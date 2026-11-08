import CoreGraphics
import CoreImage
import Foundation
import ImageIO

/// Turns a project into an image. Thread-safe: previews render on a background queue.
final class Renderer: @unchecked Sendable {
    static let shared = Renderer()

    private let ci = CIContext(options: [.cacheIntermediates: false])
    private let cache = NSCache<NSString, CGImage>()
    private let space = CGColorSpace(name: CGColorSpace.sRGB)!

    init() {
        cache.countLimit = 40
    }

    // MARK: Images

    /// Decodes an image (any format ImageIO reads), at most `maxPixels` on its longest side,
    /// with its orientation applied.
    func image(_ id: String, data: Data, maxPixels: Int = 6000) -> CGImage? {
        let key = "\(id)#\(maxPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = Self.decode(data, maxPixels: maxPixels) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func decode(_ data: Data, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(16, min(maxPixels, 12000)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Rendering

    /// Renders the project at `scale` (1 = the canvas size in pixels).
    func render(_ project: Project, scale: CGFloat, highlight: UUID? = nil) -> CGImage? {
        let W = max(1, Int((CGFloat(project.width) * scale).rounded()))
        let H = max(1, Int((CGFloat(project.height) * scale).rounded()))
        guard W <= 16000, H <= 16000,
              let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: W, height: H)
        drawBackground(project, in: canvas, scale: scale, ctx: ctx)
        let maxScreen = Int(min(6000, max(400, CGFloat(max(W, H)) * 1.2)))
        for item in project.items {
            let screen = item.screen.flatMap { id in project.assets[id].flatMap { image(id, data: $0, maxPixels: maxScreen) } }
            draw(item, screen: screen, canvas: canvas, ctx: ctx)
        }
        return ctx.makeImage()
    }

    /// Where an item lands on the canvas (its four corners, CG coordinates with the origin at the bottom left).
    func corners(of item: Item, screen: CGImage?, canvas: CGRect) -> [CGPoint] {
        if item.kind == .screenOnly, let q = item.quad, q.count == 4 {
            return q.map { CGPoint(x: canvas.minX + $0.x * canvas.width, y: canvas.maxY - $0.y * canvas.height) }
        }
        let size = deviceSize(item, screen: screen, canvas: canvas)
        let center = CGPoint(x: canvas.minX + item.x * canvas.width, y: canvas.maxY - item.y * canvas.height)
        return Projection.corners(width: size.width, height: size.height, yaw: item.yaw, pitch: item.pitch,
                                  rotation: item.rotation, center: center)
    }

    func deviceSize(_ item: Item, screen: CGImage?, canvas: CGRect) -> CGSize {
        let h = item.size * canvas.height
        let w = h * DeviceRenderer.aspect(of: item.kind, screen: screen)
        let turned = item.landscape && DeviceRenderer.canRotate(item.kind)
        // In landscape the device keeps its portrait size, turned.
        return turned ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    private func draw(_ item: Item, screen: CGImage?, canvas: CGRect, ctx: CGContext) {
        let finish = Finish.find(item.finish, for: item.kind)
        let turned = item.landscape && DeviceRenderer.canRotate(item.kind)
        let size = deviceSize(item, screen: screen, canvas: canvas)
        let pixelHeight = Int((turned ? size.width : size.height).rounded())
        guard pixelHeight >= 2 else { return }

        let flat: CGImage?
        if item.kind == .screenOnly {
            flat = screen ?? placeholder(width: 900, height: 600)
        } else {
            flat = DeviceRenderer.render(item.kind, finish: finish, screen: screen, height: pixelHeight, landscape: item.landscape)
        }
        guard let flat else { return }

        let points = corners(of: item, screen: screen, canvas: canvas)
        let shadow = item.kind == .screenOnly ? 0 : item.shadow
        let simple = item.kind != .screenOnly && item.yaw == 0 && item.pitch == 0

        if item.reflection, simple, item.rotation == 0 {
            drawReflection(flat, size: size, center: CGPoint(x: (points[0].x + points[2].x) / 2, y: (points[0].y + points[2].y) / 2), ctx: ctx)
        }

        // Where the device is drawn, and the image drawn there.
        let placed: (image: CGImage, rect: CGRect, transform: CGAffineTransform)?
        if simple {
            let center = CGPoint(x: canvas.minX + item.x * canvas.width, y: canvas.maxY - item.y * canvas.height)
            let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: -CGFloat(item.rotation) * .pi / 180)
            placed = (flat, CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), t)
        } else if let warped = warp(flat, to: points) {
            placed = (warped.image, warped.rect, .identity)
        } else {
            placed = nil
        }
        guard let placed else { return }
        let unit = max(size.width, size.height)

        if shadow > 0 {
            let s = CGFloat(shadow)
            // Two shadows, like a photo: a wide soft one for the room, a tight dark one where it touches.
            drawShadow(placed, offset: CGSize(width: 0, height: -unit * 0.05 * s), blur: unit * 0.12 * s,
                       alpha: 0.20 + 0.12 * s, ctx: ctx)
            drawShadow(placed, offset: CGSize(width: 0, height: -unit * 0.012 * s), blur: unit * 0.025 * s,
                       alpha: 0.18 + 0.16 * s, ctx: ctx)
        }

        // Turned in 3D: show the device's thickness, its side seen behind the face.
        let depth = DeviceRenderer.depth(of: item.kind) * min(size.width, size.height)
        if !simple, depth > 0.5, let side = tinted(placed.image, finish.sideColor) {
            let offset = Projection.depthOffset(depth: depth, yaw: item.yaw, pitch: item.pitch, rotation: item.rotation)
            let steps = max(2, min(24, Int(hypot(offset.dx, offset.dy).rounded())))
            for i in stride(from: steps, through: 1, by: -1) {
                let k = CGFloat(i) / CGFloat(steps)
                ctx.draw(side, in: placed.rect.offsetBy(dx: offset.dx * k, dy: offset.dy * k))
            }
        }

        ctx.saveGState()
        ctx.concatenate(placed.transform)
        ctx.draw(placed.image, in: placed.rect)
        ctx.restoreGState()
    }

    /// Only the shadow of an image: the image is drawn far away and its shadow brought back
    /// (shadow offsets are in canvas space, whatever the transform).
    private func drawShadow(_ placed: (image: CGImage, rect: CGRect, transform: CGAffineTransform),
                            offset: CGSize, blur: CGFloat, alpha: CGFloat, ctx: CGContext) {
        let far: CGFloat = 100_000
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: offset.width + far, height: offset.height), blur: blur,
                      color: CGColor(srgbRed: 0.06, green: 0.05, blue: 0.10, alpha: min(alpha, 0.75)))
        ctx.translateBy(x: -far, y: 0)
        ctx.concatenate(placed.transform)
        ctx.draw(placed.image, in: placed.rect)
        ctx.restoreGState()
    }

    /// The image's silhouette filled with one color.
    private func tinted(_ image: CGImage, _ color: CGColor) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let r = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.draw(image, in: r)
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(color)
        ctx.fill(r)
        return ctx.makeImage()
    }

    /// Maps an image onto four points (top left, top right, bottom right, bottom left; CG coordinates).
    func warp(_ image: CGImage, to p: [CGPoint]) -> (image: CGImage, rect: CGRect)? {
        guard p.count == 4, p.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: p[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: p[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: p[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: p[3]), forKey: "inputBottomLeft")
        guard let output = filter.outputImage else { return nil }
        let rect = output.extent.integral
        guard rect.width > 0, rect.height > 0, rect.width < 20000, rect.height < 20000,
              let cg = ci.createCGImage(output, from: rect, format: .RGBA8, colorSpace: space) else { return nil }
        return (cg, rect)
    }

    private func drawReflection(_ image: CGImage, size: CGSize, center: CGPoint, ctx: CGContext) {
        let bottom = center.y - size.height / 2
        let height = size.height * 0.35
        let area = CGRect(x: center.x - size.width / 2, y: bottom - height, width: size.width, height: height)
        guard let mask = gradientMask(height: Int(max(2, height))) else { return }
        ctx.saveGState()
        ctx.clip(to: area, mask: mask)
        ctx.setAlpha(0.22)
        ctx.translateBy(x: 0, y: bottom * 2)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: center.x - size.width / 2, y: bottom, width: size.width, height: size.height))
        ctx.restoreGState()
    }

    private func gradientMask(height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: 1, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        }
        return ctx.makeImage()
    }

    private func placeholder(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        DeviceRenderer.drawPlaceholder(in: CGRect(x: 0, y: 0, width: width, height: height), ctx: ctx, turned: false)
        return ctx.makeImage()
    }

    // MARK: Background

    private func drawBackground(_ p: Project, in r: CGRect, scale: CGFloat, ctx: CGContext) {
        switch p.background {
        case .transparent:
            break
        case .studio(let c):
            drawStudio(c, in: r, ctx: ctx)
        case .solid(let c):
            ctx.setFillColor(c.cgColor)
            ctx.fill(r)
        case .gradient(let colors, let angle):
            let list = colors.isEmpty ? [RGBA.white] : colors
            let a = angle * .pi / 180
            let d = (abs(r.width * cos(a)) + abs(r.height * sin(a))) / 2
            let start = CGPoint(x: r.midX - d * cos(a), y: r.midY + d * sin(a))
            let end = CGPoint(x: r.midX + d * cos(a), y: r.midY - d * sin(a))
            let locations = list.count == 1 ? [CGFloat(0)] : (0..<list.count).map { CGFloat($0) / CGFloat(list.count - 1) }
            if let g = CGGradient(colorsSpace: space, colors: list.map(\.cgColor) as CFArray, locations: locations) {
                ctx.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            drawGrain(in: r, amount: 0.03, ctx: ctx)
        case .mesh(let colors, let seed):
            let list = colors.isEmpty ? [RGBA.white] : colors
            ctx.setFillColor(list[0].cgColor)
            ctx.fill(r)
            var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: seed))
            for i in 0..<6 {
                let c = list[(i + 1) % list.count]
                let center = CGPoint(x: r.minX + rng.next() * r.width, y: r.minY + rng.next() * r.height)
                let radius = max(r.width, r.height) * (0.35 + rng.next() * 0.35)
                let stops = [RGBA(c.r, c.g, c.b, 0.85).cgColor, RGBA(c.r, c.g, c.b, 0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: space, colors: stops, locations: [0, 1]) {
                    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
                }
            }
            drawGrain(in: r, amount: 0.035, ctx: ctx)
        case .texture(let kind, let c):
            ctx.setFillColor(c.cgColor)
            ctx.fill(r)
            let ink = luminance(c) > 0.5 ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1)
            let step = max(6, 26 * scale)
            switch kind {
            case .grain:
                drawGrain(in: r, amount: 0.08, ctx: ctx)
            case .dots:
                ctx.setFillColor(ink.copy(alpha: 0.10)!)
                var y = r.minY + step / 2
                while y < r.maxY {
                    var x = r.minX + step / 2
                    while x < r.maxX {
                        ctx.fillEllipse(in: CGRect(x: x - step * 0.07, y: y - step * 0.07, width: step * 0.14, height: step * 0.14))
                        x += step
                    }
                    y += step
                }
            case .grid:
                ctx.setStrokeColor(ink.copy(alpha: 0.07)!)
                ctx.setLineWidth(max(1, scale))
                var x = r.minX
                while x <= r.maxX { ctx.move(to: CGPoint(x: x, y: r.minY)); ctx.addLine(to: CGPoint(x: x, y: r.maxY)); x += step * 1.5 }
                var y = r.minY
                while y <= r.maxY { ctx.move(to: CGPoint(x: r.minX, y: y)); ctx.addLine(to: CGPoint(x: r.maxX, y: y)); y += step * 1.5 }
                ctx.strokePath()
            case .linen:
                ctx.setStrokeColor(ink.copy(alpha: 0.035)!)
                ctx.setLineWidth(max(1, scale * 0.8))
                var t = r.minX - r.height
                while t < r.maxX {
                    ctx.move(to: CGPoint(x: t, y: r.minY)); ctx.addLine(to: CGPoint(x: t + r.height, y: r.maxY))
                    t += max(3, 4 * scale)
                }
                ctx.strokePath()
                drawGrain(in: r, amount: 0.05, ctx: ctx)
            }
        case .image(let asset, let blur, let dim):
            guard let data = p.assets[asset], let img = image(asset, data: data, maxPixels: Int(max(r.width, r.height) * 1.1)) else {
                ctx.setFillColor(RGBA.white.cgColor); ctx.fill(r); return
            }
            var drawn = img
            if blur > 0.5, let f = CIFilter(name: "CIGaussianBlur") {
                let input = CIImage(cgImage: img).clampedToExtent()
                f.setValue(input, forKey: kCIInputImageKey)
                f.setValue(blur * Double(max(img.width, img.height)) / 1000, forKey: kCIInputRadiusKey)
                if let out = f.outputImage, let cg = ci.createCGImage(out, from: CIImage(cgImage: img).extent) { drawn = cg }
            }
            let rect = DeviceRenderer.aspectFill(drawn, r)
            ctx.draw(drawn, in: CGRect(x: rect.minX, y: r.midY - rect.height / 2, width: rect.width, height: rect.height))
            if dim > 0 {
                ctx.setFillColor(CGColor(gray: 0, alpha: dim))
                ctx.fill(r)
            }
        }
    }

    /// A seamless paper backdrop: the wall gets a little darker toward the floor, the floor a little lighter
    /// toward the camera, a soft light from above, a gentle vignette and some grain.
    private func drawStudio(_ c: RGBA, in r: CGRect, ctx: CGContext) {
        func shade(_ k: Double) -> CGColor {
            CGColor(srgbRed: min(1, c.r * k), green: min(1, c.g * k), blue: min(1, c.b * k), alpha: 1)
        }
        let horizon = r.minY + r.height * 0.36
        let wall = [shade(1.04), shade(0.97), shade(0.90)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: wall, locations: [0, 0.75, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: horizon),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        // The floor, with a soft curve where it meets the wall.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: r.minX, y: r.minY, width: r.width, height: horizon - r.minY))
        let floor = [shade(0.90), shade(0.95), shade(1.0)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: floor, locations: [0, 0.35, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: horizon), end: CGPoint(x: r.midX, y: r.minY),
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
        // Key light from above.
        let light = CGPoint(x: r.midX, y: r.maxY - r.height * 0.1)
        let glow = [CGColor(gray: 1, alpha: 0.22), CGColor(gray: 1, alpha: 0)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: light, startRadius: 0, endCenter: light,
                                   endRadius: max(r.width, r.height) * 0.7, options: [])
        }
        drawVignette(in: r, strength: 0.16, ctx: ctx)
        drawGrain(in: r, amount: 0.05, ctx: ctx)
    }

    /// Darker corners, like a lens.
    private func drawVignette(in r: CGRect, strength: CGFloat, ctx: CGContext) {
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = hypot(r.width, r.height) / 2
        let colors = [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: strength)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.55, 1]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                                   options: [.drawsAfterEndLocation])
        }
    }

    private func luminance(_ c: RGBA) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    /// Fine noise over the background (looks like printed paper rather than flat pixels).
    private func drawGrain(in r: CGRect, amount: CGFloat, ctx: CGContext) {
        let size = 256
        guard let noise = Self.noiseTile(size: size) else { return }
        ctx.saveGState()
        ctx.setAlpha(amount)
        ctx.setBlendMode(.overlay)
        ctx.draw(noise, in: CGRect(x: 0, y: 0, width: size, height: size), byTiling: true)
        ctx.restoreGState()
    }

    private static let noiseImage: CGImage? = {
        let size = 256
        var rng = SeededRandom(seed: 7)
        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in pixels.indices { pixels[i] = UInt8(rng.next() * 255) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()

    private static func noiseTile(size: Int) -> CGImage? { noiseImage }
}

/// Deterministic random numbers (the same seed always gives the same background).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    /// A number in 0..<1.
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 11) & ((1 << 53) - 1)) / CGFloat(1 << 53)
    }
}

/// 3D rotation and perspective of a flat rectangle.
enum Projection {
    /// Where the back of a slab `depth` thick appears, relative to its face, once turned.
    static func depthOffset(depth: CGFloat, yaw: Double, pitch: Double, rotation: Double) -> CGVector {
        let ya = yaw * .pi / 180, pa = pitch * .pi / 180, ra = -rotation * .pi / 180
        // The back is behind the face (away from the viewer): turn the point (0, 0, depth).
        let x = -depth * sin(ya)
        let y = -depth * cos(ya) * sin(pa)
        return CGVector(dx: x * cos(ra) - y * sin(ra), dy: x * sin(ra) + y * cos(ra))
    }

    /// Corners (top left, top right, bottom right, bottom left), CG coordinates (y up).
    static func corners(width w: CGFloat, height h: CGFloat, yaw: Double, pitch: Double,
                        rotation: Double, center: CGPoint) -> [CGPoint] {
        let local: [(CGFloat, CGFloat)] = [(-w / 2, h / 2), (w / 2, h / 2), (w / 2, -h / 2), (-w / 2, -h / 2)]
        let ya = yaw * .pi / 180, pa = pitch * .pi / 180, ra = -rotation * .pi / 180
        let distance = 1.7 * max(w, h)
        return local.map { x, y in
            // Turn around the vertical axis (positive yaw: the right side goes away)…
            let x1 = x * cos(ya)
            let z1 = x * sin(ya)
            // …then around the horizontal axis (positive pitch: the top goes away).
            let y2 = y * cos(pa)
            let z2 = z1 + y * sin(pa)
            let f = distance / (distance + z2)
            let px = x1 * f, py = y2 * f
            // Rotation in the plane, then position.
            return CGPoint(x: center.x + px * cos(ra) - py * sin(ra), y: center.y + px * sin(ra) + py * cos(ra))
        }
    }
}
