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

struct InspectorView: View {
    @ObservedObject var store: ProjectStore
    @Binding var showCapture: Bool
    @ObservedObject private var export = ExportSettings.shared

    var body: some View {
        Form {
            if let item = store.selectedItem {
                deviceSection(item)
                placementSection(item)
            } else {
                Section {
                    Text(S.selectHint).foregroundStyle(.secondary)
                }
            }
            backgroundSection
            canvasSection
            exportSection
        }
        .formStyle(.grouped)
    }

    // MARK: Device

    private func deviceSection(_ item: Item) -> some View {
        Section(item.kind.title) {
            Picker(S.device, selection: Binding(get: { item.kind }, set: { kind in
                store.editSelected { i in
                    i.kind = kind
                    i.finish = Finish.all(for: kind)[0].id
                    i.quad = nil
                }
            })) {
                ForEach(DeviceKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            let finishes = Finish.all(for: item.kind)
            if finishes.count > 1 {
                Picker(S.finish, selection: Binding(get: { item.finish }, set: { f in store.editSelected { $0.finish = f } })) {
                    ForEach(finishes) { Text($0.title).tag($0.id) }
                }
            }
            HStack {
                Button(S.importDesign) { store.importDesign() }
                Button(S.paste) { store.pasteDesign() }
                Button(S.website) { showCapture = true }
            }
            .controlSize(.small)
            if item.screen != nil {
                Button(S.removeDesign, role: .destructive) { store.editSelected { $0.screen = nil } }
                    .controlSize(.small)
            }
            if DeviceRenderer.canRotate(item.kind) {
                Toggle(S.landscape, isOn: Binding(get: { item.landscape }, set: { v in store.editSelected { $0.landscape = v } }))
            }
            if item.kind == .screenOnly {
                Text(S.photoScreenHint).font(.caption).foregroundStyle(.secondary)
                Button(S.choosePhoto) { store.importBackground() }.controlSize(.small)
            }
        }
    }

    private func placementSection(_ item: Item) -> some View {
        Section(S.placement) {
            if item.kind != .screenOnly {
                slider(S.size, item.size, 0.1...1.6) { v in store.editSelected { $0.size = v } }
                slider(S.horizontal, item.x, 0...1) { v in store.editSelected { $0.x = v } }
                slider(S.vertical, item.y, 0...1) { v in store.editSelected { $0.y = v } }
                slider(S.rotation, item.rotation, -180...180, unit: "°") { v in store.editSelected { $0.rotation = v } }
                slider(S.turnSideways, item.yaw, -60...60, unit: "°") { v in store.editSelected { $0.yaw = v } }
                slider(S.tilt, item.pitch, -60...60, unit: "°") { v in store.editSelected { $0.pitch = v } }
                slider(S.shadow, item.shadow, 0...1) { v in store.editSelected { $0.shadow = v } }
                Toggle(S.reflection, isOn: Binding(get: { item.reflection }, set: { v in store.editSelected { $0.reflection = v } }))
                    .disabled(item.yaw != 0 || item.pitch != 0 || item.rotation != 0)
                    .help(S.reflectionHelp)
                Button(S.resetAngles) {
                    store.editSelected { $0.yaw = 0; $0.pitch = 0; $0.rotation = 0 }
                }
                .controlSize(.small)
            }
            HStack {
                Button { store.moveSelected(toFront: true) } label: { Image(systemName: "square.3.layers.3d.top.filled") }
                    .help(S.bringToFront)
                Button { store.moveSelected(toFront: false) } label: { Image(systemName: "square.3.layers.3d.bottom.filled") }
                    .help(S.sendToBack)
                Spacer()
                Button(S.duplicate) { store.duplicateSelected() }
                Button(S.delete, role: .destructive) { store.deleteSelected() }
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

    // MARK: Background

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
    }

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
            Picker(S.style, selection: Binding(get: { backgroundKind }, set: setBackgroundKind)) {
                ForEach(BackgroundKind.allCases) { Text($0.title).tag($0) }
            }
            switch store.project.background {
            case .studio(let c):
                colorRow(S.color, c) { new in store.edit { $0.background = .studio(new) } }
            case .solid(let c):
                colorRow(S.color, c) { new in store.edit { $0.background = .solid(new) } }
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
                colorRow(S.color, c) { new in store.edit { $0.background = .texture(kind, new) } }
            case .image(let asset, let blur, let dim):
                Button(S.choosePhoto) { store.importBackground() }.controlSize(.small)
                slider(S.blur, blur / 60, 0...1) { v in store.edit { $0.background = .image(asset: asset, blur: v * 60, dim: dim) } }
                slider(S.darken, dim, 0...0.9) { v in store.edit { $0.background = .image(asset: asset, blur: blur, dim: v) } }
            case .transparent:
                Text(S.transparentHint).font(.caption).foregroundStyle(.secondary)
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

    // MARK: Canvas and export

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
                Text("×")
                TextField(S.heightShort, value: Binding(get: { store.project.height }, set: { v in store.edit { $0.height = v } }),
                          format: .number)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private var exportSection: some View {
        Section(S.export) {
            Picker(S.format, selection: $export.format) {
                ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
            }
            Picker(S.resolution, selection: $export.scale) {
                ForEach(1...Exporter.maxScale(for: store.project), id: \.self) { s in
                    Text("\(s)x — \(store.project.width * s) × \(store.project.height * s)").tag(s)
                }
            }
            HStack {
                Button(S.exportEllipsis) { export.exportNow() }.keyboardShortcut("e", modifiers: .command)
                Button(S.batchExport) { export.batch() }.help(S.batchHelp)
                Spacer()
                Button(S.copyImage) { Exporter.copy(store.project) }
            }
            .controlSize(.small)
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
