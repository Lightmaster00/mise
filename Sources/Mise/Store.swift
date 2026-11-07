import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers

extension UTType {
    static let miseProject = UTType(exportedAs: "com.lightmaster.mise.project", conformingTo: .data)
}

/// The open project, its file, the selection and the undo history.
@MainActor
final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published private(set) var project: Project
    @Published var selection: UUID?
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published private(set) var preview: CGImage?

    private var undoStack: [Project] = []
    private var redoStack: [Project] = []
    private var lastEdit = Date.distantPast
    private var previewWork: DispatchWorkItem?
    private var previewGeneration = 0

    private init() {
        project = Template.all[0].make()
        selection = project.items.first?.id
        refreshPreview()
    }

    // MARK: Editing

    /// Applies a change. Changes close together (dragging a slider) form one undo step.
    func edit(_ change: (inout Project) -> Void) {
        var p = project
        change(&p)
        p.sanitize()
        guard p != project else { return }
        if Date().timeIntervalSince(lastEdit) > 0.6 {
            undoStack.append(project)
            if undoStack.count > 100 { undoStack.removeFirst() }
        }
        lastEdit = Date()
        redoStack.removeAll()
        project = p
        isDirty = true
        refreshPreview()
    }

    func editSelected(_ change: (inout Item) -> Void) {
        guard let id = selection else { return }
        edit { p in
            if let i = p.items.firstIndex(where: { $0.id == id }) { change(&p.items[i]) }
        }
    }

    var selectedItem: Item? { project.items.first { $0.id == selection } }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        project = previous
        lastEdit = .distantPast
        fixSelection()
        refreshPreview()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        project = next
        lastEdit = .distantPast
        fixSelection()
        refreshPreview()
    }

    private func fixSelection() {
        if selectedItem == nil { selection = project.items.last?.id }
    }

    func apply(_ template: Template) {
        // A new template keeps the designs already dropped.
        let designs = project.items.compactMap(\.screen).compactMap { id in project.assets[id].map { (id, $0) } }
        var p = template.make()
        for (i, design) in designs.prefix(p.items.count).enumerated() {
            p.assets[design.0] = design.1
            p.items[i].screen = design.0
        }
        lastEdit = .distantPast
        edit { $0 = p }
        selection = project.items.last?.id
    }

    func addItem(_ kind: DeviceKind) {
        var item = Item(kind, size: kind == .watch ? 0.6 : 0.6)
        item.sanitize()
        lastEdit = .distantPast
        edit { p in
            guard p.items.count < Project.maxItems else { return }
            item.x = 0.5 + Double(p.items.count % 4) * 0.04
            p.items.append(item)
        }
        selection = item.id
    }

    func deleteSelected() {
        guard let id = selection else { return }
        lastEdit = .distantPast
        edit { $0.items.removeAll { $0.id == id } }
        selection = project.items.last?.id
    }

    func duplicateSelected() {
        guard var item = selectedItem, project.items.count < Project.maxItems else { return }
        item.id = UUID()
        item.x += 0.05
        item.y += 0.05
        lastEdit = .distantPast
        edit { $0.items.append(item) }
        selection = item.id
    }

    func moveSelected(toFront: Bool) {
        guard let id = selection, let i = project.items.firstIndex(where: { $0.id == id }) else { return }
        lastEdit = .distantPast
        edit { p in
            let item = p.items.remove(at: i)
            if toFront { p.items.append(item) } else { p.items.insert(item, at: 0) }
        }
    }

    /// Puts a design on the selected device (or the first one).
    func setDesign(_ data: Data, on itemID: UUID? = nil) {
        guard let data = Self.normalizedImageData(data) else { return feedback(S.notAnImage) }
        let target = itemID ?? selection ?? project.items.first?.id
        lastEdit = .distantPast
        edit { p in
            let asset = p.addAsset(data)
            if let i = p.items.firstIndex(where: { $0.id == target }) {
                p.items[i].screen = asset
            } else {
                var item = Item(.floating)
                item.screen = asset
                p.items.append(item)
            }
        }
        if selection == nil { selection = project.items.last?.id }
    }

    func setBackgroundImage(_ data: Data) {
        guard let data = Self.normalizedImageData(data) else { return feedback(S.notAnImage) }
        lastEdit = .distantPast
        edit { p in
            let asset = p.addAsset(data)
            p.background = .image(asset: asset, blur: 0, dim: 0)
        }
    }

    /// Keeps any image ImageIO can read; very large images are scaled down and stored as PNG.
    static func normalizedImageData(_ data: Data) -> Data? {
        guard data.count <= 200 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        if max(w, h) <= 6000, data.count <= Project.maxAssetBytes, orientation == 1 { return data }
        guard let image = Renderer.decode(data, maxPixels: 6000) else { return nil }
        return Exporter.encode(image, format: .png)
    }

    // MARK: Preview

    /// Renders the preview in the background; only the latest request is shown.
    func refreshPreview() {
        previewWork?.cancel()
        previewGeneration += 1
        let generation = previewGeneration
        let snapshot = project
        let scale = min(1, 1400 / CGFloat(max(snapshot.width, snapshot.height)))
        let work = DispatchWorkItem {
            let image = Renderer.shared.render(snapshot, scale: scale)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard generation == ProjectStore.shared.previewGeneration else { return }
                    ProjectStore.shared.preview = image
                }
            }
        }
        previewWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.01, execute: work)
    }

    // MARK: Files

    func newProject() {
        guard confirmDiscard() else { return }
        project = Template.all[0].make()
        selection = project.items.first?.id
        fileURL = nil
        isDirty = false
        undoStack = []
        redoStack = []
        refreshPreview()
    }

    func open() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.miseProject]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func open(_ url: URL) {
        do {
            let p = try Project.decode(Data(contentsOf: url))
            project = p
            selection = p.items.last?.id
            fileURL = url
            isDirty = false
            undoStack = []
            redoStack = []
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            refreshPreview()
        } catch {
            showError(S.cannotOpen, error)
        }
    }

    @discardableResult
    func save(as: Bool = false) -> Bool {
        var url = fileURL
        if url == nil || `as` {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.miseProject]
            panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "\(S.untitled).mise"
            guard panel.runModal() == .OK, let chosen = panel.url else { return false }
            url = chosen
        }
        guard let url else { return false }
        do {
            try project.encoded().write(to: url, options: .atomic)
            fileURL = url
            isDirty = false
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            return true
        } catch {
            showError(S.cannotSave, error)
            return false
        }
    }

    /// Asks before losing unsaved changes. Returns true when it's fine to continue.
    func confirmDiscard() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = S.saveChangesTitle
        alert.informativeText = S.saveChangesDetail
        alert.addButton(withTitle: S.save)
        alert.addButton(withTitle: S.cancel)
        alert.addButton(withTitle: S.dontSave)
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    func importDesign() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        setDesign(data)
    }

    func importBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        setBackgroundImage(data)
    }

    func pasteDesign() {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            setDesign(data)
        } else if let url = (pb.readObjects(forClasses: [NSURL.self]) as? [URL])?.first(where: \.isFileURL),
                  let data = try? Data(contentsOf: url) {
            setDesign(data)
        }
    }

    func feedback(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }
}

@MainActor
func showError(_ title: String, _ error: Error) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = error.localizedDescription
    alert.runModal()
}
