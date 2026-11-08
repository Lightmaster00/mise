import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store = ProjectStore.shared
    @State private var showInspector = true
    @State private var showCapture = false
    @State private var tab: InspectorTab = .device

    var body: some View {
        NavigationSplitView {
            SceneSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            CanvasView(store: store, showCapture: $showCapture)
                .inspector(isPresented: $showInspector) {
                    InspectorView(store: store, showCapture: $showCapture, tab: $tab)
                        .inspectorColumnWidth(min: 290, ideal: 310, max: 400)
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Menu {
                    ForEach(DeviceKind.allCases.filter { $0 != .screenOnly }) { kind in
                        Button { store.addItem(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
                    }
                    Divider()
                    Button { store.addItem(.screenOnly) } label: { Label(DeviceKind.screenOnly.title, systemImage: DeviceKind.screenOnly.symbol) }
                } label: {
                    Label(S.addDevice, systemImage: "plus")
                }
                .help(S.addDevice)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.importDesign() } label: { Label(S.importDesign, systemImage: "photo.badge.plus") }
                    .help(S.importDesign)
                Button { showCapture = true } label: { Label(S.captureWebsite, systemImage: "globe") }
                    .help(S.captureWebsite)
                Button { ExportSettings.shared.exportNow() } label: {
                    Label(S.export, systemImage: "square.and.arrow.up").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .help(S.exportEllipsis)
                Button { showInspector.toggle() } label: { Label(S.inspector, systemImage: "sidebar.right") }
                    .help(S.inspector)
            }
        }
        .sheet(isPresented: $showCapture) { CaptureSheet(store: store, isPresented: $showCapture) }
        .navigationTitle(store.fileURL?.deletingPathExtension().lastPathComponent ?? S.untitled)
        .navigationSubtitle(store.isDirty ? S.edited : "")
        .onReceive(NotificationCenter.default.publisher(for: .miseShowCapture)) { _ in showCapture = true }
        .onChange(of: store.selection) { _, new in
            // Picking something on the canvas brings its settings forward.
            if new != nil, tab != .device { tab = .device }
        }
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

    /// Fits under a tile.
    var shortTitle: String {
        switch self {
        case .screenOnly: return S.kindPhotoShort
        case .phoneAndroid: return "Android"
        case .browser: return S.shortBrowser
        case .floating: return S.shortFloating
        case .businessCard: return S.shortCard
        case .paper: return S.shortPaper
        default: return title
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

// MARK: - Sidebar

/// The scene's items (top first) and the templates to start from.
private struct SceneSidebar: View {
    @ObservedObject var store: ProjectStore
    @State private var thumbnails: [String: CGImage] = [:]
    private let templates = Template.all

    var body: some View {
        List(selection: Binding(get: { store.selection }, set: { store.selection = $0 })) {
            Section(S.layers) {
                if store.project.items.isEmpty {
                    Text(S.noLayers).font(.callout).foregroundStyle(.secondary)
                }
                ForEach(store.project.items.reversed()) { item in
                    LayerRow(store: store, item: item).tag(item.id)
                        .contextMenu {
                            Button(S.duplicate) { store.selection = item.id; store.duplicateSelected() }
                            Button(S.bringToFront) { store.selection = item.id; store.moveSelected(toFront: true) }
                            Button(S.sendToBack) { store.selection = item.id; store.moveSelected(toFront: false) }
                            Divider()
                            Button(S.delete, role: .destructive) { store.selection = item.id; store.deleteSelected() }
                        }
                }
                .onMove { from, to in
                    // The list shows the top item first: work on the reversed order.
                    store.edit { p in
                        var shown = Array(p.items.reversed())
                        shown.move(fromOffsets: from, toOffset: to)
                        p.items = shown.reversed()
                    }
                }
            }
            Section(S.templates) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 10) {
                    ForEach(templates) { template in
                        TemplateCell(title: template.title, image: thumbnails[template.id]) { store.apply(template) }
                    }
                }
                .padding(.vertical, 4)
                .selectionDisabled()
            }
        }
        .listStyle(.sidebar)
        .task { await renderThumbnails() }
    }

    private func renderThumbnails() async {
        for template in templates {
            let project = template.make()
            let image = await Task.detached(priority: .utility) {
                Renderer.shared.render(project, scale: 220 / CGFloat(max(project.width, project.height)))
            }.value
            thumbnails[template.id] = image
        }
    }
}

private struct LayerRow: View {
    @ObservedObject var store: ProjectStore
    let item: Item

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.kind.symbol).frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind.title).lineLimit(1)
                Text(item.screen == nil ? S.noDesign : Finish.find(item.finish, for: item.kind).title)
                    .font(.caption).foregroundStyle(item.screen == nil ? Color.orange : Color.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 1)
    }
}

private struct TemplateCell: View {
    let title: String
    let image: CGImage?
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                // Every cell is 4:3, whatever the template's proportions.
                Color.primary.opacity(0.06)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        if let image {
                            Image(decorative: image, scale: 1).resizable().scaledToFill()
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(hover ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: hover ? 1.5 : 0.5))
                Text(title).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(title)
    }
}

// MARK: - Canvas

private struct CanvasView: View {
    @ObservedObject var store: ProjectStore
    @Binding var showCapture: Bool
    @State private var dragStart: (x: Double, y: Double)?
    @State private var dragHandle: Int?
    @State private var resizeStart: (size: Double, distance: CGFloat)?
    @State private var guides: (vertical: Bool, horizontal: Bool) = (false, false)
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
                guideOverlay(fit)
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
            .overlay {
                if store.project.items.isEmpty { emptyState }
            }
            .overlay(alignment: .bottom) {
                if let item = store.selectedItem, item.screen == nil, item.kind != .screenOnly {
                    Label(S.dropHint, systemImage: "arrow.down.doc")
                        .font(.callout)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 14)
                        .transition(.opacity)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand { store.deleteSelected() }
        .onPasteCommand(of: [.png, .tiff, .image, .fileURL]) { _ in store.pasteDesign() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone.gen3.badge.plus").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
            Text(S.emptyTitle).font(.title3.weight(.semibold))
            Text(S.emptyText).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 320)
            HStack {
                Button { store.addItem(.phone) } label: { Label(S.addPhone, systemImage: "iphone") }
                Button { store.addItem(.laptop) } label: { Label(S.addLaptop, systemImage: "laptopcomputer") }
                Button { showCapture = true } label: { Label(S.website, systemImage: "globe") }
            }
            .controlSize(.large)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func guideOverlay(_ fit: CGRect) -> some View {
        if guides.vertical {
            Rectangle().fill(Color.pink).frame(width: 1, height: fit.height).position(x: fit.midX, y: fit.midY)
        }
        if guides.horizontal {
            Rectangle().fill(Color.pink).frame(width: fit.width, height: 1).position(x: fit.midX, y: fit.midY)
        }
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
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5))
            ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .frame(width: item.kind == .screenOnly ? 14 : 10, height: item.kind == .screenOnly ? 14 : 10)
                        .position(pts[i])
            }
        }
    }

    private func dragGesture(_ fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let w = Double(fit.width), h = Double(fit.height)
                if dragStart == nil && dragHandle == nil {
                    // Start: a corner handle of a photo screen, an item, or nothing.
                    if let item = store.selectedItem {
                        let pts = corners(item, fit)
                        if let i = pts.indices.min(by: { dist(pts[$0], value.startLocation) < dist(pts[$1], value.startLocation) }),
                           dist(pts[i], value.startLocation) < 12 {
                            dragHandle = i
                            if item.kind != .screenOnly {
                                let c = CGPoint(x: pts.map(\.x).reduce(0, +) / 4, y: pts.map(\.y).reduce(0, +) / 4)
                                resizeStart = (item.size, max(1, dist(c, value.startLocation)))
                            }
                        }
                    }
                    if dragHandle == nil {
                        let hit = store.project.items.last { contains(corners($0, fit), value.startLocation) }
                        store.selection = hit?.id
                        if let hit { dragStart = (hit.x, hit.y) }
                    }
                }
                if dragHandle != nil, let resize = resizeStart, let item = store.selectedItem {
                    // Corner handle of a device: scale around its center.
                    let center = CGPoint(x: fit.minX + item.x * fit.width, y: fit.minY + item.y * fit.height)
                    let k = Double(dist(center, value.location) / resize.distance)
                    store.editSelected { $0.size = min(1.6, max(0.1, resize.size * k)) }
                } else if let handle = dragHandle {
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
                            // Snap to the middle of the canvas, and show the guide.
                            var x = start.x + dx, y = start.y + dy
                            let snapV = abs(x - 0.5) < 0.012, snapH = abs(y - 0.5) < 0.012
                            if snapV { x = 0.5 }
                            if snapH { y = 0.5 }
                            item.x = x
                            item.y = y
                            if guides.vertical != snapV || guides.horizontal != snapH { guides = (snapV, snapH) }
                        }
                    }
                }
            }
            .onEnded { _ in
                dragStart = nil
                dragHandle = nil
                resizeStart = nil
                guides = (false, false)
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
