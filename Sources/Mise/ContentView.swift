import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store = ProjectStore.shared
    @State private var showInspector = true
    @State private var showCapture = false

    var body: some View {
        NavigationSplitView {
            TemplateSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            CanvasView(store: store)
                .inspector(isPresented: $showInspector) {
                    InspectorView(store: store, showCapture: $showCapture)
                        .inspectorColumnWidth(min: 270, ideal: 300, max: 380)
                }
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(DeviceKind.allCases.filter { $0 != .screenOnly }) { kind in
                        Button { store.addItem(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
                    }
                    Divider()
                    Button { store.addItem(.screenOnly) } label: { Label(DeviceKind.screenOnly.title, systemImage: DeviceKind.screenOnly.symbol) }
                } label: {
                    Label(S.addDevice, systemImage: "plus.rectangle.on.rectangle")
                }
                .help(S.addDevice)
                Button { store.importDesign() } label: { Label(S.importDesign, systemImage: "photo.badge.plus") }
                    .help(S.importDesign)
                Button { showCapture = true } label: { Label(S.captureWebsite, systemImage: "globe") }
                    .help(S.captureWebsite)
                Button { Exporter.copy(store.project) } label: { Label(S.copyImage, systemImage: "doc.on.doc") }
                    .help(S.copyImage)
                Button { ExportSettings.shared.exportNow() } label: { Label(S.export, systemImage: "square.and.arrow.up") }
                    .help(S.export)
                Button { showInspector.toggle() } label: { Label(S.inspector, systemImage: "sidebar.right") }
                    .help(S.inspector)
            }
        }
        .sheet(isPresented: $showCapture) { CaptureSheet(store: store, isPresented: $showCapture) }
        .navigationTitle(store.fileURL?.deletingPathExtension().lastPathComponent ?? "Mise")
        .navigationSubtitle(store.isDirty ? S.edited : "")
        .onReceive(NotificationCenter.default.publisher(for: .miseShowCapture)) { _ in showCapture = true }
    }
}

extension Notification.Name {
    static let miseShowCapture = Notification.Name("MiseShowCapture")
}

extension DeviceKind {
    var title: String {
        switch self {
        case .phone: return S.kindPhone
        case .phoneAndroid: return S.kindAndroid
        case .tablet: return S.kindTablet
        case .laptop: return S.kindLaptop
        case .desktop: return S.kindDesktop
        case .watch: return S.kindWatch
        case .browser: return S.kindBrowser
        case .floating: return S.kindFloating
        case .businessCard: return S.kindCard
        case .poster: return S.kindPoster
        case .book: return S.kindBook
        case .paper: return S.kindPaper
        case .screenOnly: return S.kindPhotoScreen
        }
    }

    var symbol: String {
        switch self {
        case .phone, .phoneAndroid: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .desktop: return "display"
        case .watch: return "applewatch"
        case .browser: return "macwindow"
        case .floating: return "rectangle.on.rectangle"
        case .businessCard: return "person.text.rectangle"
        case .poster: return "doc.richtext"
        case .book: return "book.closed"
        case .paper: return "doc"
        case .screenOnly: return "perspective"
        }
    }
}

// MARK: - Templates

private struct TemplateSidebar: View {
    @ObservedObject var store: ProjectStore
    @State private var thumbnails: [String: CGImage] = [:]
    private let templates = Template.all

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(templates) { template in
                    Button { store.apply(template) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.secondary.opacity(0.08))
                                if let image = thumbnails[template.id] {
                                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            .aspectRatio(4 / 3, contentMode: .fit)
                            Text(template.title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(template.title)
                }
            }
            .padding(12)
        }
        .navigationTitle(S.templates)
        .task { await renderThumbnails() }
    }

    private func renderThumbnails() async {
        for template in templates {
            let project = template.make()
            let image = await Task.detached(priority: .utility) {
                Renderer.shared.render(project, scale: 360 / CGFloat(max(project.width, project.height)))
            }.value
            thumbnails[template.id] = image
        }
    }
}

// MARK: - Canvas

private struct CanvasView: View {
    @ObservedObject var store: ProjectStore
    @State private var dragStart: (x: Double, y: Double)?
    @State private var dragHandle: Int?
    @State private var isTargeted = false

    var body: some View {
        GeometryReader { geo in
            let fit = fitted(in: geo.size)
            ZStack(alignment: .topLeading) {
                Checkerboard()
                    .frame(width: fit.width, height: fit.height)
                    .offset(x: fit.minX, y: fit.minY)
                if let preview = store.preview {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fit.width, height: fit.height)
                        .offset(x: fit.minX, y: fit.minY)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                }
                selectionOverlay(fit)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(fit))
            .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers, location in
                handleDrop(providers, at: location, fit: fit)
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3).padding(6)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .onDeleteCommand { store.deleteSelected() }
    }

    /// The canvas rectangle inside the view, keeping its proportions.
    private func fitted(in size: CGSize) -> CGRect {
        let margin: CGFloat = 32
        let avail = CGSize(width: max(size.width - margin * 2, 10), height: max(size.height - margin * 2, 10))
        let ratio = CGFloat(store.project.width) / CGFloat(store.project.height)
        var w = avail.width, h = w / ratio
        if h > avail.height { h = avail.height; w = h * ratio }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Item corners in view coordinates (top-left origin).
    private func corners(_ item: Item, _ fit: CGRect) -> [CGPoint] {
        let canvas = CGRect(x: 0, y: 0, width: CGFloat(store.project.width), height: CGFloat(store.project.height))
        let screen = item.screen.flatMap { id in store.project.assets[id].flatMap { Renderer.shared.image(id, data: $0, maxPixels: 600) } }
        let pts = Renderer.shared.corners(of: item, screen: screen, canvas: canvas)
        let s = fit.width / canvas.width
        return pts.map { CGPoint(x: fit.minX + $0.x * s, y: fit.minY + (canvas.height - $0.y) * s) }
    }

    @ViewBuilder
    private func selectionOverlay(_ fit: CGRect) -> some View {
        if let item = store.selectedItem {
            let pts = corners(item, fit)
            Path { p in
                p.addLines(pts)
                p.closeSubpath()
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: item.kind == .screenOnly ? [] : [5, 4]))
            if item.kind == .screenOnly {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .position(pts[i])
                }
            }
        }
    }

    private func dragGesture(_ fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let w = Double(fit.width), h = Double(fit.height)
                if dragStart == nil && dragHandle == nil {
                    // Start: a corner handle of a photo screen, an item, or nothing.
                    if let item = store.selectedItem, item.kind == .screenOnly {
                        let pts = corners(item, fit)
                        if let i = pts.indices.min(by: { dist(pts[$0], value.startLocation) < dist(pts[$1], value.startLocation) }),
                           dist(pts[i], value.startLocation) < 14 {
                            dragHandle = i
                        }
                    }
                    if dragHandle == nil {
                        let hit = store.project.items.last { contains(corners($0, fit), value.startLocation) }
                        store.selection = hit?.id
                        if let hit { dragStart = (hit.x, hit.y) }
                    }
                }
                if let handle = dragHandle {
                    let x = Double((value.location.x - fit.minX) / fit.width)
                    let y = Double((value.location.y - fit.minY) / fit.height)
                    store.editSelected { item in
                        guard var q = item.quad, q.count == 4 else { return }
                        q[handle] = CGPoint(x: x, y: y)
                        item.quad = q
                    }
                } else if let start = dragStart {
                    let dx = Double(value.translation.width) / w, dy = Double(value.translation.height) / h
                    store.editSelected { item in
                        if item.kind == .screenOnly, var q = item.quad {
                            // Move the whole screen: shift the four corners from where they were.
                            let cx = q.map(\.x).reduce(0, +) / 4, cy = q.map(\.y).reduce(0, +) / 4
                            let tx = start.x + dx - cx, ty = start.y + dy - cy
                            q = q.map { CGPoint(x: $0.x + tx, y: $0.y + ty) }
                            item.quad = q
                        } else {
                            item.x = start.x + dx
                            item.y = start.y + dy
                        }
                    }
                }
            }
            .onEnded { _ in
                dragStart = nil
                dragHandle = nil
            }
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    /// Point in polygon (ray casting).
    private func contains(_ poly: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private func handleDrop(_ providers: [NSItemProvider], at location: CGPoint, fit: CGRect) -> Bool {
        guard let provider = providers.first else { return false }
        let target = store.project.items.last { contains(corners($0, fit), location) }?.id
        let deliver: (Data) -> Void = { data in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if target == nil, store.project.items.isEmpty == false, store.selection == nil {
                        store.setDesign(data, on: store.project.items.last?.id)
                    } else {
                        store.setDesign(data, on: target)
                    }
                }
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, let data = try? Data(contentsOf: url) { deliver(data) }
            }
            return true
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let data { deliver(data) }
        }
        return true
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 10
            for row in 0..<Int(size.height / s + 1) {
                for col in 0..<Int(size.width / s + 1) where (row + col) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)),
                             with: .color(.gray.opacity(0.15)))
                }
            }
        }
        .background(Color.white)
    }
}

// MARK: - Website capture

private struct CaptureSheet: View {
    @ObservedObject var store: ProjectStore
    @Binding var isPresented: Bool
    @State private var address = ""
    @State private var width: WebCapture.Width = .desktop
    @State private var fullPage = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(S.captureWebsite).font(.headline)
            TextField("https://example.com", text: $address)
                .textFieldStyle(.roundedBorder)
                .onSubmit(capture)
            Picker(S.width, selection: $width) {
                Text(S.kindPhone).tag(WebCapture.Width.phone)
                Text(S.kindTablet).tag(WebCapture.Width.tablet)
                Text(S.desktopWidth).tag(WebCapture.Width.desktop)
            }
            .pickerStyle(.segmented)
            Toggle(S.fullPage, isOn: $fullPage)
            if let error {
                Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Text(S.captureHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button(S.cancel) { isPresented = false }.keyboardShortcut(.cancelAction)
                Button(S.capture, action: capture)
                    .keyboardShortcut(.defaultAction)
                    .disabled(working || WebCapture.normalizedURL(address) == nil)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func capture() {
        guard let url = WebCapture.normalizedURL(address) else { return error = S.invalidAddress }
        working = true
        error = nil
        WebCapture.capture(url, width: width, fullPage: fullPage) { result in
            working = false
            switch result {
            case .success(let data):
                store.setDesign(data)
                isPresented = false
            case .failure(let e):
                error = e.localizedDescription
            }
        }
    }
}
