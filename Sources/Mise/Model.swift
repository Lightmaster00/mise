import CoreGraphics
import Foundation

/// A color stored as hex ("#RRGGBB" or "#RRGGBBAA").
struct RGBA: Codable, Equatable, Hashable {
    var r: Double, g: Double, b: Double, a: Double = 1

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        } else {
            self.init(Double((v >> 24) & 0xFF) / 255, Double((v >> 16) & 0xFF) / 255,
                      Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        }
    }

    var hex: String {
        func c(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return a >= 1 ? String(format: "#%02X%02X%02X", c(r), c(g), c(b))
            : String(format: "#%02X%02X%02X%02X", c(r), c(g), c(b), c(a))
    }

    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(hex)
    }

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = RGBA(hex: s) ?? RGBA(1, 1, 1)
    }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
}

/// What's behind the devices.
enum Background: Codable, Equatable {
    case solid(RGBA)
    case gradient([RGBA], angle: Double)
    /// Soft blurred color blobs, like a mesh gradient.
    case mesh([RGBA], seed: Int)
    /// A colored surface with a pattern.
    case texture(TextureKind, RGBA)
    /// One of the user's photos.
    case image(asset: String, blur: Double, dim: Double)
    case transparent

    enum TextureKind: String, Codable, CaseIterable { case grain, dots, grid, linen }
}

/// Everything that can be put on the canvas.
enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    case phone, phoneAndroid, tablet, laptop, desktop, watch, browser, floating
    case businessCard, poster, book, paper
    /// Only the design, mapped by four corners onto a photo (photo scenes).
    case screenOnly
    var id: String { rawValue }

    var isPrint: Bool { [.businessCard, .poster, .book, .paper].contains(self) }
}

/// One device (or print item) on the canvas.
struct Item: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: DeviceKind
    /// Finish of the body (see `Finish.all(for:)`).
    var finish: String
    /// The design shown on its screen (key into `Project.assets`), or nil for the placeholder.
    var screen: String?
    /// Center, as a fraction of the canvas (0…1, origin top left).
    var x: Double = 0.5
    var y: Double = 0.5
    /// Height of the device as a fraction of the canvas height.
    var size: Double = 0.7
    /// Rotation in the plane, degrees.
    var rotation: Double = 0
    /// 3D rotation around the vertical axis (left/right) and the horizontal axis, degrees.
    var yaw: Double = 0
    var pitch: Double = 0
    var landscape = false
    var shadow: Double = 0.5
    var reflection = false
    /// For `.screenOnly`: the four corners of the screen in the photo (fractions, clockwise from top left).
    var quad: [CGPoint]?

    init(_ kind: DeviceKind, finish: String? = nil, x: Double = 0.5, y: Double = 0.5, size: Double = 0.7,
         rotation: Double = 0, yaw: Double = 0, pitch: Double = 0, shadow: Double = 0.5) {
        self.kind = kind
        self.finish = finish ?? Finish.all(for: kind).first?.id ?? "default"
        self.x = x; self.y = y; self.size = size
        self.rotation = rotation; self.yaw = yaw; self.pitch = pitch; self.shadow = shadow
    }

    /// Values outside their range (an edited or corrupted file) are brought back in range.
    mutating func sanitize() {
        func clamp(_ v: Double, _ lo: Double, _ hi: Double, _ fallback: Double) -> Double {
            v.isFinite ? min(max(v, lo), hi) : fallback
        }
        x = clamp(x, -0.5, 1.5, 0.5)
        y = clamp(y, -0.5, 1.5, 0.5)
        size = clamp(size, 0.05, 3, 0.7)
        rotation = clamp(rotation, -180, 180, 0)
        yaw = clamp(yaw, -60, 60, 0)
        pitch = clamp(pitch, -60, 60, 0)
        shadow = clamp(shadow, 0, 1, 0.5)
        if let q = quad {
            quad = q.count == 4 && q.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
                ? q.map { CGPoint(x: min(max($0.x, -1), 2), y: min(max($0.y, -1), 2)) } : nil
        }
        if kind == .screenOnly, quad == nil {
            quad = [CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.7, y: 0.2), CGPoint(x: 0.7, y: 0.8), CGPoint(x: 0.3, y: 0.8)]
        }
        if Finish.all(for: kind).contains(where: { $0.id == finish }) == false {
            finish = Finish.all(for: kind).first?.id ?? "default"
        }
    }
}

/// A mockup: canvas, background, devices and the images they use.
struct Project: Codable, Equatable {
    static let maxItems = 24
    static let maxSide = 8000
    static let maxAssetBytes = 80 * 1024 * 1024

    var version = 1
    var width = 1600
    var height = 1200
    var background: Background = .gradient([RGBA(hex: "#E9E4FF")!, RGBA(hex: "#FFE3EC")!], angle: 135)
    var items: [Item] = []
    /// PNG/JPEG data of the images, by identifier.
    var assets: [String: Data] = [:]

    var canvasSize: CGSize { CGSize(width: width, height: height) }

    mutating func sanitize() {
        width = min(max(width, 64), Self.maxSide)
        height = min(max(height, 64), Self.maxSide)
        if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
        for i in items.indices { items[i].sanitize() }
        // Drop images nobody uses, and any oversized one.
        var used = Set(items.compactMap(\.screen))
        if case .image(let asset, _, _) = background { used.insert(asset) }
        assets = assets.filter { used.contains($0.key) && $0.value.count <= Self.maxAssetBytes }
        if case .image(let asset, let blur, let dim) = background {
            background = assets[asset] == nil ? .solid(.white)
                : .image(asset: asset, blur: min(max(blur.isFinite ? blur : 0, 0), 60), dim: min(max(dim.isFinite ? dim : 0, 0), 0.9))
        }
    }

    /// Reads a project file, refusing anything malformed or absurdly large.
    static func decode(_ data: Data) throws -> Project {
        guard data.count < 600 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        var p = try JSONDecoder().decode(Project.self, from: data)
        p.sanitize()
        return p
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Stores an image and returns its identifier.
    mutating func addAsset(_ data: Data) -> String {
        let id = UUID().uuidString
        assets[id] = data
        return id
    }
}

/// Canvas size presets.
struct CanvasPreset: Identifiable {
    let id: String
    let width: Int
    let height: Int

    static let all: [CanvasPreset] = [
        CanvasPreset(id: "4:3", width: 1600, height: 1200),
        CanvasPreset(id: "16:9", width: 1920, height: 1080),
        CanvasPreset(id: "1:1", width: 1080, height: 1080),
        CanvasPreset(id: "4:5", width: 1080, height: 1350),
        CanvasPreset(id: "9:16", width: 1080, height: 1920),
        CanvasPreset(id: "Dribbble", width: 1600, height: 1200),
        CanvasPreset(id: "Twitter", width: 1600, height: 900),
        CanvasPreset(id: "App Store", width: 1290, height: 2796),
    ]
}
