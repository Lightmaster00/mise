import AppKit
import SwiftUI

/// Export options shared by the toolbar, the menu and the inspector.
@MainActor
final class ExportSettings: ObservableObject {
    static let shared = ExportSettings()
    @Published var format: ExportFormat = .png
    @Published var scale = 2

    func exportNow() {
        Exporter.export(ProjectStore.shared.project, scale: scale, format: format)
    }

    func batch() {
        let store = ProjectStore.shared
        Exporter.batch(store.project, itemID: store.selection, scale: scale, format: format)
    }
}

/// The inspector's three pages.
enum InspectorTab: String, CaseIterable, Identifiable {
    case device, scene, export
    var id: String { rawValue }
    var title: String {
        switch self {
        case .device: return S.tabDevice
        case .scene: return S.tabScene
        case .export: return S.export
        }
    }
}

struct InspectorView: View {
    @ObservedObject var store: ProjectStore
    @Binding var showCapture: Bool
    @Binding var tab: InspectorTab
    @ObservedObject private var export = ExportSettings.shared
    @State private var fineTuning = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(InspectorTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
            Form {
                switch tab {
                case .device:
                    if let item = store.selectedItem {
                        designSection(item)
                        deviceSection(item)
                        if item.kind != .screenOnly {
                            angleSection(item)
                            lookSection(item)
                        }
                        arrangeSection
                    } else {
                        noSelection
                    }
                case .scene:
                    backgroundSection
                    lightSection
                    canvasSection
                case .export:
                    exportSection
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: Device page

    private var noSelection: some View {
        Group {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "cursorarrow.click.2").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
                    Text(S.selectHint).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            Section(S.addDevice) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(DeviceKind.allCases) { kind in
                        Tile(title: kind.shortTitle, symbol: kind.symbol, selected: false) { store.addItem(kind) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func designSection(_ item: Item) -> some View {
        Section(S.design) {
            HStack(spacing: 12) {
                DesignWell(store: store, item: item)
                VStack(alignment: .leading, spacing: 6) {
                    if item.kind == .screenOnly {
                        Text(S.photoScreenHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button(S.choosePhoto) { store.importBackground() }
                    }
                    Button(item.screen == nil ? S.chooseImage : S.replaceImage) { store.importDesign() }
                    Menu(S.otherSources) {
                        Button(S.pasteImage) { store.pasteDesign() }
                        Button(S.captureWebsite) { showCapture = true }
                        if item.screen != nil {
                            Divider()
                            Button(S.removeDesign, role: .destructive) { store.editSelected { $0.screen = nil } }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .controlSize(.small)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
    }

    private func deviceSection(_ item: Item) -> some View {
        Section(S.device) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(DeviceKind.allCases) { kind in
                    Tile(title: kind.shortTitle, symbol: kind.symbol, selected: item.kind == kind) {
                        store.editSelected { i in
                            i.kind = kind
                            i.finish = Finish.all(for: kind)[0].id
                            i.quad = nil
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            let finishes = Finish.all(for: item.kind)
            if finishes.count > 1 {
                LabeledContent(S.finish) {
                    HStack(spacing: 7) {
                        ForEach(finishes) { f in
                            Swatch(finish: f, selected: item.finish == f.id) { store.editSelected { $0.finish = f.id } }
                        }
                    }
                }
            }
            if DeviceRenderer.canRotate(item.kind) {
                Toggle(S.landscape, isOn: Binding(get: { item.landscape }, set: { v in store.editSelected { $0.landscape = v } }))
            }
        }
    }

    private func angleSection(_ item: Item) -> some View {
        Section(S.angle) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(AnglePreset.all) { preset in
                    AngleTile(preset: preset, selected: preset.matches(item)) {
                        store.editSelected { preset.apply(to: &$0) }
                    }
                }
            }
            .padding(.vertical, 2)
            DisclosureGroup(S.fineTuning, isExpanded: $fineTuning) {
                slider(S.rotation, item.rotation, -180...180, unit: "°") { v in store.editSelected { $0.rotation = v } }
                slider(S.turnSideways, item.yaw, -60...60, unit: "°") { v in store.editSelected { $0.yaw = v } }
                slider(S.tilt, item.pitch, -60...60, unit: "°") { v in store.editSelected { $0.pitch = v } }
                slider(S.horizontal, item.x, 0...1) { v in store.editSelected { $0.x = v } }
                slider(S.vertical, item.y, 0...1) { v in store.editSelected { $0.y = v } }
            }
        }
    }

    private func lookSection(_ item: Item) -> some View {
        Section(S.look) {
            slider(S.size, item.size, 0.1...1.6) { v in store.editSelected { $0.size = v } }
            slider(S.shadow, item.shadow, 0...1) { v in store.editSelected { $0.shadow = v } }
            Toggle(S.reflection, isOn: Binding(get: { item.reflection }, set: { v in store.editSelected { $0.reflection = v } }))
                .disabled(item.yaw != 0 || item.pitch != 0 || item.rotation != 0)
                .help(S.reflectionHelp)
        }
    }

    private var arrangeSection: some View {
        Section {
            HStack(spacing: 8) {
                Button { store.duplicateSelected() } label: { Label(S.duplicate, systemImage: "plus.square.on.square") }
                Menu {
                    Button(S.bringToFront) { store.moveSelected(toFront: true) }
                    Button(S.sendToBack) { store.moveSelected(toFront: false) }
                } label: {
                    Label(S.arrange, systemImage: "square.3.layers.3d")
                }
                .fixedSize()
                Spacer()
                Button(role: .destructive) { store.deleteSelected() } label: { Label(S.delete, systemImage: "trash") }
            }
            .controlSize(.small)
        }
    }

    private func slider(_ title: String, _ value: Double, _ range: ClosedRange<Double>, unit: String = "%",
                        _ set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(unit == "%" ? "\(Int((value * 100).rounded())) %" : "\(Int(value.rounded()))\(unit)")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { value }, set: set), in: range)
                .controlSize(.small)
        }
    }

    // MARK: Scene page

    private enum BackgroundKind: String, CaseIterable, Identifiable {
        case studio, solid, gradient, mesh, texture, image, transparent
        var id: String { rawValue }
        var title: String {
            switch self {
            case .studio: return S.bgStudio
            case .solid: return S.bgSolid
            case .gradient: return S.bgGradient
            case .mesh: return S.bgMesh
            case .texture: return S.bgTexture
            case .image: return S.bgPhoto
            case .transparent: return S.bgTransparent
            }
        }
        var symbol: String {
            switch self {
            case .studio: return "light.overhead.left"
            case .solid: return "square.fill"
            case .gradient: return "circle.lefthalf.filled"
            case .mesh: return "aqi.medium"
            case .texture: return "square.grid.3x3.fill"
            case .image: return "photo"
            case .transparent: return "checkerboard.rectangle"
            }
        }
    }

    /// Calm colors that suit a mockup, one click away.
    private static let swatches = ["#EFEDE9", "#ECE8F2", "#DDE7E1", "#EAE3D8", "#E2C48E", "#B9C9B5", "#C9D3E6",
                                   "#E8CDD2", "#2B2A33", "#14121F"].compactMap { RGBA(hex: $0) }

    private var backgroundKind: BackgroundKind {
        switch store.project.background {
        case .studio: return .studio
        case .solid: return .solid
        case .gradient: return .gradient
        case .mesh: return .mesh
        case .texture: return .texture
        case .image: return .image
        case .transparent: return .transparent
        }
    }

    private var palette: [RGBA] {
        switch store.project.background {
        case .solid(let c), .texture(_, let c), .studio(let c): return [c]
        case .gradient(let c, _), .mesh(let c, _): return c
        default: return [RGBA(hex: "#EDE9FF")!, RGBA(hex: "#FFE4EE")!]
        }
    }

    private var backgroundSection: some View {
        Section(S.background) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(BackgroundKind.allCases) { kind in
                    Tile(title: kind.title, symbol: kind.symbol, selected: backgroundKind == kind) { setBackgroundKind(kind) }
                }
            }
            .padding(.vertical, 2)
            switch store.project.background {
            case .studio(let c):
                swatchRow(c) { new in store.edit { $0.background = .studio(new) } }
            case .solid(let c):
                swatchRow(c) { new in store.edit { $0.background = .solid(new) } }
            case .gradient(let colors, let angle):
                ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                    colorRow(S.colorNumber(i + 1), c) { new in
                        store.edit { p in
                            var list = colors
                            list[i] = new
                            p.background = .gradient(list, angle: angle)
                        }
                    }
                }
                slider(S.angle, angle, 0...360, unit: "°") { v in store.edit { $0.background = .gradient(colors, angle: v) } }
            case .mesh(let colors, let seed):
                ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                    colorRow(S.colorNumber(i + 1), c) { new in
                        store.edit { p in
                            var list = colors
                            list[i] = new
                            p.background = .mesh(list, seed: seed)
                        }
                    }
                }
                Button(S.shuffle) { store.edit { $0.background = .mesh(colors, seed: Int.random(in: 0...999_999)) } }
                    .controlSize(.small)
            case .texture(let kind, let c):
                Picker(S.pattern, selection: Binding(get: { kind }, set: { k in store.edit { $0.background = .texture(k, c) } })) {
                    ForEach(Background.TextureKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                swatchRow(c) { new in store.edit { $0.background = .texture(kind, new) } }
            case .image(let asset, let blur, let dim):
                Button(S.choosePhoto) { store.importBackground() }.controlSize(.small)
                slider(S.blur, blur / 60, 0...1) { v in store.edit { $0.background = .image(asset: asset, blur: v * 60, dim: dim) } }
                slider(S.darken, dim, 0...0.9) { v in store.edit { $0.background = .image(asset: asset, blur: blur, dim: v) } }
            case .transparent:
                Text(S.transparentHint).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Preset colors plus a picker for anything else.
    private func swatchRow(_ current: RGBA, _ set: @escaping (RGBA) -> Void) -> some View {
        LabeledContent(S.color) {
            HStack(spacing: 6) {
                ForEach(Self.swatches, id: \.hex) { c in
                    Button { set(c) } label: {
                        Circle()
                            .fill(Color(.sRGB, red: c.r, green: c.g, blue: c.b))
                            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3).opacity(c.hex == current.hex ? 1 : 0))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help(c.hex)
                }
                ColorPicker("", selection: Binding(get: {
                    Color(.sRGB, red: current.r, green: current.g, blue: current.b)
                }, set: { c in
                    if let ns = NSColor(c).usingColorSpace(.sRGB) {
                        set(RGBA(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent)))
                    }
                }), supportsOpacity: false)
                .labelsHidden()
            }
        }
    }

    private func setBackgroundKind(_ kind: BackgroundKind) {
        let colors = palette
        switch kind {
        case .studio: store.edit { $0.background = .studio(colors[0]) }
        case .solid: store.edit { $0.background = .solid(colors[0]) }
        case .gradient: store.edit { $0.background = .gradient(colors.count >= 2 ? Array(colors.prefix(3)) : [colors[0], .white], angle: 135) }
        case .mesh: store.edit { $0.background = .mesh(colors.count >= 3 ? colors : colors + [RGBA(hex: "#FFC6B0")!, RGBA(hex: "#B8A6FF")!], seed: 11) }
        case .texture: store.edit { $0.background = .texture(.grain, colors[0]) }
        case .image: store.importBackground()
        case .transparent: store.edit { $0.background = .transparent }
        }
    }

    private func colorRow(_ title: String, _ color: RGBA, _ set: @escaping (RGBA) -> Void) -> some View {
        ColorPicker(title, selection: Binding(get: {
            Color(.sRGB, red: color.r, green: color.g, blue: color.b, opacity: color.a)
        }, set: { c in
            if let ns = NSColor(c).usingColorSpace(.sRGB) {
                set(RGBA(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent)))
            }
        }), supportsOpacity: false)
    }

    private var lightSection: some View {
        Section(S.light) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                Tile(title: S.lightNone, symbol: "sun.max", selected: store.project.light == nil) {
                    store.edit { $0.light = nil }
                }
                ForEach(Light.Kind.allCases) { kind in
                    Tile(title: kind.title, symbol: kind.symbol, selected: store.project.light?.kind == kind) {
                        store.edit { p in
                            var l = p.light ?? Light(kind: kind)
                            l.kind = kind
                            p.light = l
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            if let l = store.project.light {
                slider(S.strength, l.strength, 0...1) { v in store.edit { $0.light?.strength = v } }
                slider(S.angle, l.angle, 0...360, unit: "°") { v in store.edit { $0.light?.angle = v } }
                Button(S.shuffle) { store.edit { $0.light?.seed = Int.random(in: 0...999_999) } }
                    .controlSize(.small)
            }
        }
    }

    private var canvasSection: some View {
        Section(S.canvas) {
            Picker(S.size, selection: Binding(get: {
                CanvasPreset.all.first { $0.width == store.project.width && $0.height == store.project.height }?.id ?? "custom"
            }, set: { id in
                if let preset = CanvasPreset.all.first(where: { $0.id == id }) {
                    store.edit { $0.width = preset.width; $0.height = preset.height }
                }
            })) {
                ForEach(CanvasPreset.all) { Text("\($0.id) — \($0.width) × \($0.height)").tag($0.id) }
                Text(S.custom).tag("custom")
            }
            HStack {
                TextField(S.widthShort, value: Binding(get: { store.project.width }, set: { v in store.edit { $0.width = v } }),
                          format: .number)
                Text("×").foregroundStyle(.secondary)
                TextField(S.heightShort, value: Binding(get: { store.project.height }, set: { v in store.edit { $0.height = v } }),
                          format: .number)
                Text("px").foregroundStyle(.secondary)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Export page

    private var exportSection: some View {
        Group {
            Section {
                Picker(S.format, selection: $export.format) {
                    ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker(S.resolution, selection: $export.scale) {
                    ForEach(1...Exporter.maxScale(for: store.project), id: \.self) { s in
                        Text("\(s)x — \(store.project.width * s) × \(store.project.height * s)").tag(s)
                    }
                }
            }
            Section {
                Button { export.exportNow() } label: {
                    Label(S.exportEllipsis, systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button { Exporter.copy(store.project) } label: {
                    Label(S.copyImage, systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            Section {
                Button(S.batchExport) { export.batch() }
                Text(S.batchHelp).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Inspector parts

/// A square choice with a symbol and a short title: devices, backgrounds, light.
struct Tile: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .regular)).frame(height: 20)
                Text(title).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.8))
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(hover ? 0.08 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(title)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// A finish shown as a small metal bead.
private struct Swatch: View {
    let finish: Finish
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LinearGradient(colors: [Color(cgColor: finish.edge.1.cgColor), Color(cgColor: finish.edge.0.cgColor)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(finish.title)
    }
}

/// One-click angles, like a photographer's usual shots.
struct AnglePreset: Identifiable {
    let id: String
    let title: String
    let rotation: Double, yaw: Double, pitch: Double

    static var all: [AnglePreset] {
        [
            AnglePreset(id: "front", title: S.angleFront, rotation: 0, yaw: 0, pitch: 0),
            AnglePreset(id: "left", title: S.angleLeft, rotation: 0, yaw: 32, pitch: 0),
            AnglePreset(id: "right", title: S.angleRight, rotation: 0, yaw: -32, pitch: 0),
            AnglePreset(id: "tilted", title: S.angleTilted, rotation: -8, yaw: -22, pitch: 8),
            AnglePreset(id: "isoLeft", title: S.angleIsoLeft, rotation: -28, yaw: 30, pitch: 38),
            AnglePreset(id: "isoRight", title: S.angleIsoRight, rotation: 28, yaw: -30, pitch: 38),
            AnglePreset(id: "flat", title: S.angleFlat, rotation: 0, yaw: 0, pitch: 50),
            AnglePreset(id: "leaning", title: S.angleLeaning, rotation: 12, yaw: 0, pitch: 0),
            AnglePreset(id: "dynamic", title: S.angleDynamic, rotation: 14, yaw: 24, pitch: -12),
        ]
    }

    func matches(_ item: Item) -> Bool {
        abs(item.rotation - rotation) < 0.5 && abs(item.yaw - yaw) < 0.5 && abs(item.pitch - pitch) < 0.5
    }

    func apply(to item: inout Item) {
        item.rotation = rotation
        item.yaw = yaw
        item.pitch = pitch
        if yaw != 0 || pitch != 0 || rotation != 0 { item.reflection = false }
    }
}

/// An angle preset drawn as the outline of a phone seen from that angle.
private struct AngleTile: View {
    let preset: AnglePreset
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Canvas { ctx, size in
                    let pts = Projection.corners(width: 15, height: 30, yaw: preset.yaw, pitch: preset.pitch,
                                                 rotation: preset.rotation, center: CGPoint(x: size.width / 2, y: size.height / 2))
                    // Projection works with y up; the canvas has y down.
                    let flipped = pts.map { CGPoint(x: $0.x, y: size.height - $0.y) }
                    var path = Path()
                    path.addLines(flipped)
                    path.closeSubpath()
                    ctx.fill(path, with: .color(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08)))
                    ctx.stroke(path, with: .color(selected ? Color.accentColor : Color.primary.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                }
                .frame(height: 40)
                Text(preset.title).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.8))
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(hover ? 0.08 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(preset.title)
    }
}

/// The current design, small, and a place to drop a new one.
private struct DesignWell: View {
    @ObservedObject var store: ProjectStore
    let item: Item
    @State private var targeted = false

    var body: some View {
        let image = item.screen.flatMap { id in store.project.assets[id].flatMap { Renderer.shared.image(id, data: $0, maxPixels: 240) } }
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "photo.badge.plus").font(.system(size: 20, weight: .light)).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(targeted ? Color.accentColor : Color.primary.opacity(0.15),
                              style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: image == nil ? [4, 3] : []))
        }
        .frame(width: 64, height: 64)
        .contentShape(Rectangle())
        .onTapGesture { store.importDesign() }
        .onDrop(of: [.image, .fileURL], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }
            let id = item.id
            let deliver: (Data) -> Void = { data in
                DispatchQueue.main.async { MainActor.assumeIsolated { store.setDesign(data, on: id) } }
            }
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, let data = try? Data(contentsOf: url) { deliver(data) }
                }
            } else {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in if let data { deliver(data) } }
            }
            return true
        }
        .help(S.dropHint)
    }
}

extension Light.Kind {
    var title: String {
        switch self {
        case .leaves: return S.lightLeaves
        case .window: return S.lightWindow
        case .blinds: return S.lightBlinds
        }
    }
    var symbol: String {
        switch self {
        case .leaves: return "leaf"
        case .window: return "window.casement"
        case .blinds: return "blinds.horizontal.closed"
        }
    }
}

extension Background.TextureKind {
    var title: String {
        switch self {
        case .grain: return S.texGrain
        case .dots: return S.texDots
        case .grid: return S.texGrid
        case .linen: return S.texLinen
        }
    }
}
