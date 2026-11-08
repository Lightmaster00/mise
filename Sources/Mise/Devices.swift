import CoreGraphics
import Foundation

/// A color finish for a device body.
struct Finish: Identifiable, Equatable {
    let id: String
    let title: String
    /// Polished edge: dark, light, mid tones.
    let edge: (RGBA, RGBA, RGBA)
    /// Flat surfaces (laptop lid and base, monitor back, watch case, paper, book cloth).
    let surface: RGBA

    static func == (a: Finish, b: Finish) -> Bool { a.id == b.id }

    /// The device's side, seen when it is turned in 3D: a darker shade of the edge.
    var sideColor: CGColor {
        let base = ["paper", "kraft"].contains(id) ? surface : edge.2
        let k = ["paper", "kraft"].contains(id) ? 0.82 : 0.62
        return CGColor(srgbRed: base.r * k, green: base.g * k, blue: base.b * k, alpha: 1)
    }

    private static func f(_ id: String, _ title: String, _ e1: String, _ e2: String, _ e3: String, _ s: String) -> Finish {
        Finish(id: id, title: title, edge: (RGBA(hex: e1)!, RGBA(hex: e2)!, RGBA(hex: e3)!), surface: RGBA(hex: s)!)
    }

    static let graphite = f("graphite", S.finishGraphite, "#2A2B30", "#6B6D75", "#45464C", "#3A3B40")
    static let silver = f("silver", S.finishSilver, "#A9ABB2", "#F4F5F7", "#CDCED3", "#D9DADF")
    static let gold = f("gold", S.finishGold, "#B39A78", "#F3E6D1", "#D6C3A5", "#E3D3BB")
    static let blue = f("blue", S.finishBlue, "#2E3A52", "#7D8DAD", "#4C5A78", "#3F4C68")
    static let white = f("white", S.finishWhite, "#C9CBD1", "#FFFFFF", "#E6E7EB", "#F2F2F4")
    static let spaceGray = f("spacegray", S.finishSpaceGray, "#55575E", "#A3A5AC", "#7D7F86", "#8A8C93")
    static let midnight = f("midnight", S.finishMidnight, "#1E2430", "#4D586B", "#323A49", "#2B3240")
    static let light = f("light", S.finishLight, "#D0D0D5", "#F6F6F8", "#E8E8EC", "#F0F0F3")
    static let dark = f("dark", S.finishDark, "#1C1C1F", "#3A3A3F", "#2A2A2E", "#2A2A2E")
    static let paperWhite = f("paper", S.finishPaper, "#E6E3DC", "#FFFFFF", "#F4F2EE", "#FBFAF7")
    static let kraft = f("kraft", S.finishKraft, "#B08A60", "#D9BC94", "#C6A47A", "#CDAE86")
    static let cloth = f("cloth", S.finishCloth, "#1F2A44", "#3B4A6E", "#2C3958", "#2C3958")
    static let none = f("none", S.finishNone, "#000000", "#000000", "#000000", "#000000")

    static func all(for kind: DeviceKind) -> [Finish] {
        switch kind {
        case .phone: return [graphite, silver, gold, blue, white]
        case .phoneAndroid: return [graphite, white, blue]
        case .tablet: return [spaceGray, silver, blue]
        case .laptop: return [silver, spaceGray, midnight, gold]
        case .desktop: return [silver, dark, white]
        case .watch: return [midnight, silver, gold]
        case .browser: return [light, dark]
        case .floating: return [light, dark, none]
        case .businessCard, .poster, .paper: return [paperWhite, kraft]
        case .book: return [cloth, paperWhite, kraft]
        case .screenOnly: return [none]
        }
    }

    static func find(_ id: String, for kind: DeviceKind) -> Finish {
        all(for: kind).first { $0.id == id } ?? all(for: kind)[0]
    }
}

/// Draws devices in vector, at any size, with the design on their screen.
enum DeviceRenderer {
    /// Width / height of the whole drawing (portrait orientation).
    static func aspect(of kind: DeviceKind, screen: CGImage?) -> CGFloat {
        switch kind {
        case .phone: return 0.49
        case .phoneAndroid: return 0.47
        case .tablet: return 0.705
        case .laptop: return 1.617
        case .desktop: return 1.231
        case .watch: return 0.415
        case .browser: return 1.46
        case .floating, .screenOnly:
            guard let s = screen, s.height > 0 else { return 0.75 }
            return min(max(CGFloat(s.width) / CGFloat(s.height), 0.25), 4)
        case .businessCard: return 1.545
        case .poster: return 0.667
        case .book: return 0.70
        case .paper: return 0.707
        }
    }

    /// Thickness, as a fraction of the shorter side, shown when the item is turned in 3D (0 = none).
    static func depth(of kind: DeviceKind) -> CGFloat {
        switch kind {
        case .phone, .phoneAndroid: return 0.10
        case .tablet: return 0.04
        case .book: return 0.13
        case .businessCard: return 0.025
        case .poster, .paper: return 0.006
        case .browser, .floating: return 0.012
        case .laptop, .desktop, .watch, .screenOnly: return 0
        }
    }

    /// Phones, tablets and print items can be turned to landscape.
    static func canRotate(_ kind: DeviceKind) -> Bool {
        [.phone, .phoneAndroid, .tablet, .poster, .paper, .businessCard].contains(kind)
    }

    /// Renders a device `height` pixels tall (portrait height, before a landscape turn).
    static func render(_ kind: DeviceKind, finish: Finish, screen: CGImage?, height: Int, landscape: Bool) -> CGImage? {
        let h = CGFloat(min(max(height, 8), 6000))
        let w = (h * aspect(of: kind, screen: screen)).rounded()
        let turned = landscape && canRotate(kind)
        let outW = Int(turned ? h : w), outH = Int(turned ? w : h)
        guard let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        if turned {
            // Draw the portrait device turned a quarter clockwise; its screen content is turned back.
            ctx.translateBy(x: CGFloat(outW), y: 0)
            ctx.rotate(by: .pi / 2)
        }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        draw(kind, in: rect, finish: finish, screen: screen, ctx: ctx, contentTurned: turned)
        return ctx.makeImage()
    }

    // MARK: Drawing

    private static func draw(_ kind: DeviceKind, in r: CGRect, finish: Finish, screen: CGImage?, ctx: CGContext, contentTurned: Bool) {
        switch kind {
        case .phone: drawPhone(r, finish, screen, ctx, contentTurned, android: false)
        case .phoneAndroid: drawPhone(r, finish, screen, ctx, contentTurned, android: true)
        case .tablet: drawTablet(r, finish, screen, ctx, contentTurned)
        case .laptop: drawLaptop(r, finish, screen, ctx)
        case .desktop: drawDesktop(r, finish, screen, ctx)
        case .watch: drawWatch(r, finish, screen, ctx)
        case .browser: drawBrowser(r, finish, screen, ctx)
        case .floating: drawFloating(r, finish, screen, ctx)
        case .businessCard: drawPaper(r, finish, screen, ctx, contentTurned, corner: 0.035, tape: false)
        case .poster: drawPaper(r, finish, screen, ctx, contentTurned, corner: 0.004, tape: true)
        case .paper: drawPaper(r, finish, screen, ctx, contentTurned, corner: 0.004, tape: false)
        case .book: drawBook(r, finish, screen, ctx)
        case .screenOnly: drawScreen(screen, in: r, radius: 0, ctx: ctx, turned: false)
        }
    }

    static func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let rad = max(0, min(radius, min(r.width, r.height) / 2 - 0.01))
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    private static func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient? {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)
    }

    private static func gray(_ g: CGFloat, _ a: CGFloat) -> CGColor { CGColor(srgbRed: g, green: g, blue: g, alpha: a) }

    /// Polished metal: light catches the corners of the band, with a diagonal key light from the top left.
    private static func fillMetal(_ path: CGPath, _ r: CGRect, _ f: Finish, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let (dark, light, mid) = f.edge
        if let g = gradient([dark, light, mid, mid, light, dark].map(\.cgColor), [0, 0.03, 0.10, 0.90, 0.97, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.midY), end: CGPoint(x: r.maxX, y: r.midY), options: [])
        }
        if let g = gradient([gray(1, 0.22), gray(1, 0), gray(0, 0), gray(0, 0.20)], [0, 0.35, 0.65, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
        }
        ctx.restoreGState()
    }

    /// A thin highlight along an edge, bright at the top, fading toward the bottom (light from above).
    private static func rimLight(_ path: CGPath, _ r: CGRect, width: CGFloat, strength: CGFloat, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(width)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        if let g = gradient([gray(1, strength), gray(1, strength * 0.25), gray(1, strength * 0.05)], [0, 0.5, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        }
        ctx.restoreGState()
    }

    private static func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func fillVertical(_ path: CGPath, _ r: CGRect, _ colors: [CGColor], _ locations: [CGFloat], _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let g = gradient(colors, locations) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        }
        ctx.restoreGState()
    }

    private static func fillHorizontal(_ path: CGPath, _ r: CGRect, _ colors: [CGColor], _ locations: [CGFloat], _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let g = gradient(colors, locations) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.midY), end: CGPoint(x: r.maxX, y: r.midY), options: [])
        }
        ctx.restoreGState()
    }

    /// A camera lens: dark glass, a blue tint and a small reflection.
    private static func lens(_ c: CGPoint, _ d: CGFloat, _ ctx: CGContext) {
        let r = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
        ctx.setFillColor(CGColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1))
        ctx.fillEllipse(in: r)
        ctx.setFillColor(CGColor(srgbRed: 0.16, green: 0.20, blue: 0.36, alpha: 0.8))
        ctx.fillEllipse(in: r.insetBy(dx: d * 0.25, dy: d * 0.25))
        ctx.setFillColor(gray(1, 0.45))
        ctx.fillEllipse(in: CGRect(x: c.x + d * 0.08, y: c.y + d * 0.08, width: d * 0.18, height: d * 0.18))
    }

    /// Draws the design aspect-filled into a rounded screen, then glass: a faint diagonal glare
    /// and a little depth at the top edge.
    static func drawScreen(_ image: CGImage?, in r: CGRect, radius: CGFloat, ctx: CGContext, turned: Bool, glass: Bool = true) {
        ctx.saveGState()
        ctx.addPath(rounded(r, radius))
        ctx.clip()
        if let image {
            if turned {
                // The device is drawn turned: turn the design back so it reads correctly.
                ctx.translateBy(x: r.midX, y: r.midY)
                ctx.rotate(by: -.pi / 2)
                let tr = CGRect(x: -r.height / 2, y: -r.width / 2, width: r.height, height: r.width)
                ctx.draw(image, in: aspectFill(image, tr))
            } else {
                ctx.draw(image, in: aspectFill(image, r))
            }
        } else {
            drawPlaceholder(in: r, ctx: ctx, turned: turned)
        }
        ctx.restoreGState()
        guard glass else { return }
        ctx.saveGState()
        ctx.addPath(rounded(r, radius))
        ctx.clip()
        // Glare: a soft band across the upper left of the glass.
        let glare = CGMutablePath()
        glare.move(to: CGPoint(x: r.minX, y: r.maxY))
        glare.addLine(to: CGPoint(x: r.minX + r.width * 0.62, y: r.maxY))
        glare.addLine(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.55))
        glare.closeSubpath()
        ctx.addPath(glare)
        ctx.clip()
        if let g = gradient([gray(1, 0.09), gray(1, 0.0)], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY),
                                   end: CGPoint(x: r.minX + r.width * 0.32, y: r.maxY - r.height * 0.28), options: [])
        }
        ctx.restoreGState()
    }

    static func aspectFill(_ image: CGImage, _ r: CGRect) -> CGRect {
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        guard iw > 0, ih > 0 else { return r }
        let scale = max(r.width / iw, r.height / ih)
        let w = iw * scale, h = ih * scale
        // Align to the top: screenshots are read from the top.
        return CGRect(x: r.midX - w / 2, y: r.maxY - h, width: w, height: h)
    }

    // MARK: Placeholder screen

    /// A calm, believable app screen used until a design is dropped: a mobile app when tall,
    /// a dashboard when wide.
    static func drawPlaceholder(in rect: CGRect, ctx: CGContext, turned: Bool) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        var r = rect
        if turned {
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.rotate(by: -.pi / 2)
            r = CGRect(x: -rect.height / 2, y: -rect.width / 2, width: rect.height, height: rect.width)
        }
        if r.width > r.height * 1.15 { placeholderDesktop(r, ctx) } else { placeholderMobile(r, ctx) }
    }

    private static let ink = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 1)
    private static let ink2 = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 0.42)
    private static let ink3 = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 0.12)
    private static let paper = CGColor(srgbRed: 0.965, green: 0.96, blue: 0.95, alpha: 1)
    private static let accentA = CGColor(srgbRed: 0.23, green: 0.25, blue: 0.56, alpha: 1)
    private static let accentB = CGColor(srgbRed: 0.53, green: 0.42, blue: 0.80, alpha: 1)
    private static let warm = CGColor(srgbRed: 0.95, green: 0.62, blue: 0.47, alpha: 1)
    private static let sage = CGColor(srgbRed: 0.55, green: 0.72, blue: 0.62, alpha: 1)

    private static func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGColor, _ ctx: CGContext) {
        ctx.setFillColor(c)
        ctx.addPath(rounded(CGRect(x: x, y: y, width: w, height: h), h / 2))
        ctx.fillPath()
    }

    private static func card(_ r: CGRect, radius: CGFloat, _ ctx: CGContext, fill: CGColor = CGColor(gray: 1, alpha: 1)) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -radius * 0.15), blur: radius * 0.9,
                      color: CGColor(srgbRed: 0.1, green: 0.1, blue: 0.2, alpha: 0.08))
        ctx.setFillColor(fill)
        ctx.addPath(rounded(r, radius))
        ctx.fillPath()
        ctx.restoreGState()
    }

    private static func placeholderMobile(_ r: CGRect, _ ctx: CGContext) {
        let u = r.width / 100   // 1 unit = 1% of the width
        ctx.setFillColor(paper)
        ctx.fill(r)
        let left = r.minX + 6 * u, right = r.maxX - 6 * u, inner = right - left
        var y = r.maxY - 7 * u
        // Status bar.
        bar(left + 2 * u, y - 2.6 * u, 9 * u, 2.6 * u, ink, ctx)
        bar(right - 14 * u, y - 2.4 * u, 6 * u, 2.4 * u, ink2, ctx)
        bar(right - 6 * u, y - 2.4 * u, 6 * u, 2.4 * u, ink, ctx)
        y -= 11 * u
        // Greeting and avatar.
        bar(left, y - 2.6 * u, 28 * u, 2.6 * u, ink2, ctx)
        bar(left, y - 9.5 * u, 58 * u, 5 * u, ink, ctx)
        ctx.setFillColor(warm)
        ctx.fillEllipse(in: CGRect(x: right - 11 * u, y: y - 10 * u, width: 11 * u, height: 11 * u))
        y -= 15 * u
        // Hero card with a soft gradient and two rings.
        let hero = CGRect(x: left, y: y - 44 * u, width: inner, height: 44 * u)
        ctx.saveGState()
        ctx.addPath(rounded(hero, 6 * u)); ctx.clip()
        if let g = gradient([accentA, accentB], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: hero.minX, y: hero.minY), end: CGPoint(x: hero.maxX, y: hero.maxY), options: [])
        }
        ctx.setStrokeColor(gray(1, 0.14))
        ctx.setLineWidth(5 * u)
        ctx.strokeEllipse(in: CGRect(x: hero.maxX - 34 * u, y: hero.midY - 6 * u, width: 50 * u, height: 50 * u))
        ctx.setLineWidth(2 * u)
        ctx.strokeEllipse(in: CGRect(x: hero.maxX - 22 * u, y: hero.minY - 14 * u, width: 30 * u, height: 30 * u))
        ctx.restoreGState()
        bar(hero.minX + 6 * u, hero.maxY - 9 * u, 22 * u, 2.4 * u, gray(1, 0.6), ctx)
        bar(hero.minX + 6 * u, hero.maxY - 19 * u, 42 * u, 6 * u, gray(1, 1), ctx)
        bar(hero.minX + 6 * u, hero.minY + 6 * u, 26 * u, 7 * u, gray(1, 0.95), ctx)
        y = hero.minY - 7 * u
        // Chips.
        var x = left
        for (w, selected) in [(20.0, true), (17.0, false), (23.0, false)] {
            bar(x, y - 6.5 * u, CGFloat(w) * u, 6.5 * u, selected ? ink : ink3, ctx)
            x += CGFloat(w) * u + 2.5 * u
        }
        y -= 13 * u
        // List rows.
        let dots = [warm, sage, accentB, warm]
        var i = 0
        while y - 16 * u > r.minY + 20 * u, i < 6 {
            let row = CGRect(x: left, y: y - 15 * u, width: inner, height: 15 * u)
            card(row, radius: 4 * u, ctx)
            ctx.setFillColor(dots[i % dots.count].copy(alpha: 0.85)!)
            ctx.addPath(rounded(CGRect(x: row.minX + 3 * u, y: row.minY + 3 * u, width: 9 * u, height: 9 * u), 2.6 * u))
            ctx.fillPath()
            bar(row.minX + 16 * u, row.midY + 0.6 * u, [44.0, 36, 50, 40][i % 4] * u, 2.8 * u, ink, ctx)
            bar(row.minX + 16 * u, row.midY - 4 * u, [28.0, 34, 22, 30][i % 4] * u, 2.2 * u, ink2, ctx)
            bar(row.maxX - 15 * u, row.midY - 1.3 * u, 11 * u, 2.6 * u, ink3, ctx)
            y -= 18.5 * u
            i += 1
        }
        // Tab bar.
        let tab = CGRect(x: r.minX, y: r.minY, width: r.width, height: 17 * u)
        ctx.setFillColor(gray(1, 0.92))
        ctx.fill(tab)
        ctx.setFillColor(ink3)
        ctx.fill(CGRect(x: r.minX, y: tab.maxY - 0.3 * u, width: r.width, height: 0.3 * u))
        for n in 0..<4 {
            let cx = r.minX + r.width * (CGFloat(n) + 0.5) / 4
            ctx.setFillColor(n == 0 ? accentA : ink3)
            ctx.addPath(rounded(CGRect(x: cx - 3 * u, y: tab.minY + 8 * u, width: 6 * u, height: 6 * u), 1.8 * u))
            ctx.fillPath()
        }
        bar(r.midX - 17 * u, r.minY + 2 * u, 34 * u, 1.3 * u, ink, ctx)
    }

    private static func placeholderDesktop(_ r: CGRect, _ ctx: CGContext) {
        let u = r.height / 100   // 1 unit = 1% of the height
        ctx.setFillColor(paper)
        ctx.fill(r)
        // Sidebar.
        let side = CGRect(x: r.minX, y: r.minY, width: max(22 * u, r.width * 0.17), height: r.height)
        ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.925, blue: 0.915, alpha: 1))
        ctx.fill(side)
        ctx.setFillColor(accentA)
        ctx.addPath(rounded(CGRect(x: side.minX + 4 * u, y: r.maxY - 11 * u, width: 6 * u, height: 6 * u), 1.6 * u)); ctx.fillPath()
        bar(side.minX + 12 * u, r.maxY - 9.2 * u, side.width * 0.4, 2.4 * u, ink, ctx)
        var y = r.maxY - 22 * u
        for n in 0..<7 {
            if n == 1 {
                ctx.setFillColor(gray(1, 1))
                ctx.addPath(rounded(CGRect(x: side.minX + 2.5 * u, y: y - 2.6 * u, width: side.width - 5 * u, height: 7 * u), 1.8 * u))
                ctx.fillPath()
            }
            ctx.setFillColor(n == 1 ? accentA : ink3)
            ctx.addPath(rounded(CGRect(x: side.minX + 4.5 * u, y: y - 0.9 * u, width: 3.6 * u, height: 3.6 * u), 1 * u)); ctx.fillPath()
            bar(side.minX + 10.5 * u, y - 0.1 * u, side.width * [0.45, 0.38, 0.5, 0.33, 0.42, 0.36, 0.4][n], 2 * u, n == 1 ? ink : ink2, ctx)
            y -= 9 * u
        }
        // Main area: title, three stats, a chart and a table.
        let left = side.maxX + 5 * u, right = r.maxX - 5 * u, w = right - left
        bar(left, r.maxY - 11 * u, w * 0.22, 4 * u, ink, ctx)
        bar(right - w * 0.14, r.maxY - 12 * u, w * 0.14, 5.4 * u, accentA, ctx)
        let statTop = r.maxY - 18 * u, statH = 18 * u, gap = 3 * u
        let statW = (w - 2 * gap) / 3
        for n in 0..<3 {
            let c = CGRect(x: left + CGFloat(n) * (statW + gap), y: statTop - statH, width: statW, height: statH)
            card(c, radius: 2.4 * u, ctx)
            bar(c.minX + 3 * u, c.maxY - 5.5 * u, statW * 0.35, 2 * u, ink2, ctx)
            bar(c.minX + 3 * u, c.maxY - 12.5 * u, statW * 0.5, 4.4 * u, ink, ctx)
            bar(c.minX + 3 * u, c.minY + 2.6 * u, statW * 0.22, 2 * u, [sage, warm, sage][n], ctx)
        }
        let chart = CGRect(x: left, y: r.minY + 30 * u, width: w, height: statTop - statH - gap - (r.minY + 30 * u))
        guard chart.height > 10 * u else { return }
        card(chart, radius: 2.4 * u, ctx)
        bar(chart.minX + 3 * u, chart.maxY - 5.5 * u, w * 0.16, 2.4 * u, ink, ctx)
        // A smooth line with a soft area under it.
        let plot = chart.insetBy(dx: 4 * u, dy: 4 * u).offsetBy(dx: 0, dy: -2 * u)
        let values: [CGFloat] = [0.32, 0.45, 0.38, 0.58, 0.52, 0.70, 0.64, 0.82, 0.76, 0.9]
        let points = values.enumerated().map { i, v in
            CGPoint(x: plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1), y: plot.minY + plot.height * 0.8 * v)
        }
        let line = CGMutablePath()
        line.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let mx = (a.x + b.x) / 2
            line.addCurve(to: b, control1: CGPoint(x: mx, y: a.y), control2: CGPoint(x: mx, y: b.y))
        }
        let area = line.mutableCopy()!
        area.addLine(to: CGPoint(x: plot.maxX, y: plot.minY))
        area.addLine(to: CGPoint(x: plot.minX, y: plot.minY))
        area.closeSubpath()
        ctx.saveGState()
        ctx.addPath(area); ctx.clip()
        if let g = gradient([accentB.copy(alpha: 0.28)!, accentB.copy(alpha: 0)!], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: plot.midX, y: plot.maxY), end: CGPoint(x: plot.midX, y: plot.minY), options: [])
        }
        ctx.restoreGState()
        stroke(line, accentA, 0.7 * u, ctx)
        // Table.
        var rowY = chart.minY - gap - 6 * u
        for n in 0..<3 where rowY > r.minY + 2 * u {
            bar(left, rowY, w * 0.18, 2 * u, ink, ctx)
            bar(left + w * 0.35, rowY, w * 0.12, 2 * u, ink2, ctx)
            bar(right - w * 0.1, rowY, w * 0.1, 2 * u, n == 0 ? sage : ink3, ctx)
            ctx.setFillColor(ink3)
            ctx.fill(CGRect(x: left, y: rowY - 3 * u, width: w, height: max(1, 0.15 * u)))
            rowY -= 7 * u
        }
    }

    // MARK: Devices

    private static func drawPhone(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool, android: Bool) {
        let W = r.width
        // Side buttons, behind the body.
        let bw = W * 0.014
        let buttons: [(x: CGFloat, y: CGFloat, len: CGFloat)] = android
            ? [(r.maxX - bw * 0.35, 0.70, 0.10), (r.maxX - bw * 0.35, 0.56, 0.06)]
            : [(r.minX - bw * 0.65, 0.78, 0.035), (r.minX - bw * 0.65, 0.70, 0.07), (r.minX - bw * 0.65, 0.60, 0.07),
               (r.maxX - bw * 0.35, 0.715, 0.11)]
        for b in buttons {
            let rect = CGRect(x: b.x, y: r.minY + r.height * b.y - r.height * b.len / 2, width: bw, height: r.height * b.len)
            fillHorizontal(rounded(rect, bw / 2), rect, [f.edge.0.cgColor, f.edge.1.cgColor, f.edge.0.cgColor], [0, 0.5, 1], ctx)
        }
        let body = r.insetBy(dx: W * 0.006, dy: W * 0.006)
        let radius = W * (android ? 0.11 : 0.165)
        let bodyPath = rounded(body, radius)
        fillMetal(bodyPath, body, f, ctx)
        rimLight(bodyPath, body, width: W * 0.012, strength: 0.55, ctx)
        // Black glass around the screen, with a fine dark line where it meets the frame.
        let glass = body.insetBy(dx: W * 0.017, dy: W * 0.017)
        let glassPath = rounded(glass, radius - W * 0.017)
        ctx.setFillColor(CGColor(srgbRed: 0.015, green: 0.015, blue: 0.02, alpha: 1))
        ctx.addPath(glassPath); ctx.fillPath()
        stroke(glassPath, gray(0, 0.6), W * 0.004, ctx)
        let s = glass.insetBy(dx: W * 0.024, dy: W * 0.024)
        drawScreen(screen, in: s, radius: radius - W * 0.041, ctx: ctx, turned: turned)
        // Camera: a pill (island) or a punch hole.
        if android {
            let d = W * 0.042
            let c = CGPoint(x: s.midX, y: s.maxY - W * 0.045)
            ctx.setFillColor(gray(0, 1))
            ctx.fillEllipse(in: CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d))
            lens(c, d * 0.62, ctx)
        } else {
            let pill = CGRect(x: s.midX - W * 0.145, y: s.maxY - W * 0.032 - W * 0.082, width: W * 0.29, height: W * 0.082)
            ctx.setFillColor(gray(0, 1))
            ctx.addPath(rounded(pill, pill.height / 2)); ctx.fillPath()
            lens(CGPoint(x: pill.maxX - pill.height * 0.62, y: pill.midY), pill.height * 0.42, ctx)
        }
    }

    private static func drawTablet(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool) {
        let W = r.width
        let body = r.insetBy(dx: W * 0.004, dy: W * 0.004)
        let radius = W * 0.07
        let bodyPath = rounded(body, radius)
        fillMetal(bodyPath, body, f, ctx)
        rimLight(bodyPath, body, width: W * 0.007, strength: 0.5, ctx)
        let glass = body.insetBy(dx: W * 0.010, dy: W * 0.010)
        let glassPath = rounded(glass, radius - W * 0.010)
        ctx.setFillColor(CGColor(srgbRed: 0.015, green: 0.015, blue: 0.02, alpha: 1))
        ctx.addPath(glassPath); ctx.fillPath()
        stroke(glassPath, gray(0, 0.6), W * 0.002, ctx)
        let s = glass.insetBy(dx: W * 0.042, dy: W * 0.042)
        drawScreen(screen, in: s, radius: W * 0.028, ctx: ctx, turned: turned)
        lens(CGPoint(x: glass.midX, y: glass.maxY - W * 0.021), W * 0.013, ctx)
    }

    private static func drawLaptop(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let total = r.width
        let L = total / 1.14
        let baseH = L * 0.042
        let lid = CGRect(x: r.midX - L / 2, y: r.minY + baseH * 0.62, width: L, height: r.height - baseH * 0.62)
        // Lid: a thin metal edge, the black bezel, the screen and its camera.
        let lidPath = rounded(lid, L * 0.03)
        fillMetal(lidPath, lid, f, ctx)
        rimLight(lidPath, lid, width: L * 0.004, strength: 0.5, ctx)
        let bezel = lid.insetBy(dx: L * 0.0055, dy: L * 0.0055)
        ctx.setFillColor(CGColor(srgbRed: 0.02, green: 0.02, blue: 0.025, alpha: 1))
        ctx.addPath(rounded(bezel, L * 0.025)); ctx.fillPath()
        let s = CGRect(x: bezel.minX + L * 0.016, y: bezel.minY + L * 0.028, width: bezel.width - L * 0.032,
                       height: bezel.height - L * 0.044)
        drawScreen(screen, in: s, radius: L * 0.007, ctx: ctx, turned: false)
        lens(CGPoint(x: bezel.midX, y: bezel.maxY - L * 0.008), L * 0.006, ctx)
        // Hinge: a dark band where the lid meets the base.
        let hinge = CGRect(x: lid.minX + L * 0.04, y: r.minY + baseH * 0.55, width: L - L * 0.08, height: baseH * 0.35)
        fillVertical(rounded(hinge, hinge.height / 2), hinge, [gray(0.08, 1), gray(0.22, 1)], [0, 1], ctx)
        // Base: the front edge of the body, light on top, dark underneath, with a thumb notch.
        let baseRect = CGRect(x: r.minX, y: r.minY, width: total, height: baseH)
        let base = CGPath(roundedRect: baseRect, cornerWidth: baseH * 1.2, cornerHeight: baseH * 0.5, transform: nil)
        let surf = f.surface.cgColor
        fillVertical(base, baseRect, [f.edge.1.cgColor, surf, f.edge.2.cgColor, f.edge.0.cgColor], [0, 0.25, 0.7, 1], ctx)
        // Light catching the top edge of the base.
        ctx.setFillColor(gray(1, 0.65))
        ctx.fill(CGRect(x: r.minX + baseH, y: baseRect.maxY - max(1, baseH * 0.08), width: total - baseH * 2, height: max(1, baseH * 0.08)))
        let notch = CGRect(x: r.midX - L * 0.075, y: baseRect.maxY - baseH * 0.42, width: L * 0.15, height: baseH * 0.42)
        let notchPath = CGPath(roundedRect: notch, cornerWidth: notch.height, cornerHeight: notch.height * 0.9, transform: nil)
        fillVertical(notchPath, notch, [f.edge.0.cgColor, f.edge.2.cgColor], [0, 1], ctx)
    }

    private static func drawDesktop(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let D = r.width
        let displayH = D * 0.5925
        let display = CGRect(x: r.minX, y: r.maxY - displayH, width: D, height: displayH)
        // Stand: a gently lit neck, then a thin foot catching the light.
        let neck = CGRect(x: r.midX - D * 0.085, y: r.minY + D * 0.018, width: D * 0.17, height: r.height - displayH + D * 0.01)
        fillHorizontal(rounded(neck, D * 0.006), neck,
                       [f.edge.0.cgColor, f.edge.2.cgColor, f.edge.1.cgColor, f.edge.2.cgColor, f.edge.0.cgColor],
                       [0, 0.2, 0.5, 0.8, 1], ctx)
        ctx.saveGState()
        ctx.addPath(rounded(neck, D * 0.006)); ctx.clip()
        if let g = gradient([gray(0, 0.35), gray(0, 0)], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: neck.midX, y: neck.maxY), end: CGPoint(x: neck.midX, y: neck.maxY - neck.height * 0.3), options: [])
        }
        ctx.restoreGState()
        let foot = CGRect(x: r.midX - D * 0.16, y: r.minY, width: D * 0.32, height: D * 0.024)
        fillVertical(rounded(foot, foot.height / 2), foot, [f.edge.1.cgColor, f.edge.2.cgColor, f.edge.0.cgColor], [0, 0.4, 1], ctx)
        let displayPath = rounded(display, D * 0.016)
        fillMetal(displayPath, display, f, ctx)
        rimLight(displayPath, display, width: D * 0.004, strength: 0.45, ctx)
        let bezel = display.insetBy(dx: D * 0.0045, dy: D * 0.0045)
        ctx.setFillColor(CGColor(srgbRed: 0.02, green: 0.02, blue: 0.025, alpha: 1))
        ctx.addPath(rounded(bezel, D * 0.013)); ctx.fillPath()
        drawScreen(screen, in: bezel.insetBy(dx: D * 0.012, dy: D * 0.012), radius: D * 0.004, ctx: ctx, turned: false)
    }

    private static func drawWatch(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let C = r.height / 2.0          // case height
        let cw = C * 0.83
        let caseRect = CGRect(x: r.midX - cw / 2, y: r.midY - C / 2, width: cw, height: C)
        // Band: a soft strap, rounded like a cylinder, a little darker toward its ends.
        let band = CGRect(x: r.midX - cw * 0.39, y: r.minY, width: cw * 0.78, height: r.height)
        let bandPath = rounded(band, cw * 0.14)
        let b = f.surface
        func shade(_ k: Double) -> CGColor { CGColor(srgbRed: b.r * k, green: b.g * k, blue: b.b * k, alpha: 1) }
        fillHorizontal(bandPath, band, [shade(0.62), shade(0.95), shade(1.05), shade(0.95), shade(0.62)], [0, 0.18, 0.5, 0.82, 1], ctx)
        ctx.saveGState()
        ctx.addPath(bandPath); ctx.clip()
        if let g = gradient([gray(0, 0.38), gray(0, 0), gray(0, 0), gray(0, 0.38)], [0, 0.22, 0.78, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: band.midX, y: band.maxY), end: CGPoint(x: band.midX, y: band.minY), options: [])
        }
        // Holes in the lower strap.
        ctx.setFillColor(gray(0, 0.35))
        for i in 0..<3 {
            let d = cw * 0.045
            ctx.fillEllipse(in: CGRect(x: band.midX - d / 2, y: r.minY + r.height * (0.10 + CGFloat(i) * 0.05), width: d, height: d))
        }
        ctx.restoreGState()
        // Crown with ridges, and the side button.
        let crown = CGRect(x: caseRect.maxX - cw * 0.03, y: caseRect.midY + C * 0.06, width: cw * 0.075, height: C * 0.17)
        fillVertical(rounded(crown, cw * 0.02), crown, [f.edge.1.cgColor, f.edge.2.cgColor, f.edge.0.cgColor], [0, 0.5, 1], ctx)
        ctx.setFillColor(gray(0, 0.18))
        var y = crown.minY + crown.height * 0.15
        while y < crown.maxY - crown.height * 0.1 {
            ctx.fill(CGRect(x: crown.minX + crown.width * 0.4, y: y, width: crown.width * 0.6, height: max(1, crown.height * 0.04)))
            y += crown.height * 0.11
        }
        let button = CGRect(x: caseRect.maxX - cw * 0.02, y: caseRect.midY - C * 0.2, width: cw * 0.045, height: C * 0.14)
        fillVertical(rounded(button, cw * 0.015), button, [f.edge.1.cgColor, f.edge.0.cgColor], [0, 1], ctx)
        let casePath = rounded(caseRect, cw * 0.24)
        fillMetal(casePath, caseRect, f, ctx)
        rimLight(casePath, caseRect, width: cw * 0.02, strength: 0.6, ctx)
        let glass = caseRect.insetBy(dx: cw * 0.033, dy: cw * 0.033)
        let glassPath = rounded(glass, cw * 0.21)
        ctx.setFillColor(gray(0, 1))
        ctx.addPath(glassPath); ctx.fillPath()
        drawScreen(screen, in: glass.insetBy(dx: cw * 0.055, dy: cw * 0.055), radius: cw * 0.155, ctx: ctx, turned: false)
    }

    private static func drawBrowser(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let W = r.width
        let dark = f.id == "dark"
        let window = rounded(r, W * 0.012)
        ctx.saveGState()
        ctx.addPath(window); ctx.clip()
        let barH = W * 0.058
        let bar = CGRect(x: r.minX, y: r.maxY - barH, width: W, height: barH)
        fillVertical(CGPath(rect: bar, transform: nil), bar,
                     dark ? [CGColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1), CGColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1)]
                          : [gray(0.965, 1), gray(0.925, 1)], [0, 1], ctx)
        ctx.setFillColor(dark ? gray(0, 0.5) : gray(0, 0.10))
        ctx.fill(CGRect(x: r.minX, y: bar.minY - max(1, W * 0.0008), width: W, height: max(1, W * 0.0008)))
        let content = CGRect(x: r.minX, y: r.minY, width: W, height: r.height - barH - max(1, W * 0.0008))
        drawScreen(screen, in: content, radius: 0, ctx: ctx, turned: false, glass: false)
        ctx.restoreGState()
        // Traffic lights.
        let d = barH * 0.24
        for (i, hex) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
            ctx.setFillColor(RGBA(hex: hex)!.cgColor)
            ctx.fillEllipse(in: CGRect(x: r.minX + barH * 0.42 + CGFloat(i) * d * 1.75, y: bar.midY - d / 2, width: d, height: d))
        }
        // Back and forward arrows.
        ctx.setStrokeColor(dark ? gray(1, 0.35) : gray(0, 0.28))
        ctx.setLineWidth(max(1, barH * 0.05))
        ctx.setLineCap(.round)
        for (i, dir) in [-1.0, 1.0].enumerated() {
            let cx = r.minX + barH * 2.4 + CGFloat(i) * barH * 0.55
            ctx.move(to: CGPoint(x: cx + CGFloat(dir) * barH * 0.07, y: bar.midY + barH * 0.13))
            ctx.addLine(to: CGPoint(x: cx - CGFloat(dir) * barH * 0.07, y: bar.midY))
            ctx.addLine(to: CGPoint(x: cx + CGFloat(dir) * barH * 0.07, y: bar.midY - barH * 0.13))
        }
        ctx.strokePath()
        // Address field with a lock and the address.
        let field = CGRect(x: r.midX - W * 0.2, y: bar.midY - barH * 0.23, width: W * 0.4, height: barH * 0.46)
        ctx.setFillColor(dark ? gray(0.27, 1) : gray(1, 1))
        ctx.addPath(rounded(field, field.height * 0.3)); ctx.fillPath()
        ctx.setFillColor(dark ? gray(1, 0.35) : gray(0, 0.22))
        let text = CGRect(x: field.midX - field.width * 0.18, y: field.midY - field.height * 0.11, width: field.width * 0.36, height: field.height * 0.22)
        ctx.addPath(rounded(text, text.height / 2)); ctx.fillPath()
        ctx.addPath(rounded(CGRect(x: text.minX - field.height * 0.42, y: field.midY - field.height * 0.14, width: field.height * 0.22, height: field.height * 0.26), field.height * 0.05))
        ctx.fillPath()
        // Hairline border.
        stroke(window, dark ? gray(1, 0.14) : gray(0, 0.14), max(1, W * 0.0008), ctx)
    }

    private static func drawFloating(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let radius = f.id == "none" ? 0 : min(r.width, r.height) * 0.035
        drawScreen(screen, in: r, radius: radius, ctx: ctx, turned: false, glass: false)
        if f.id != "none" {
            let path = rounded(r.insetBy(dx: 0.5, dy: 0.5), radius)
            stroke(path, f.id == "dark" ? gray(1, 0.16) : gray(0, 0.10), max(1, min(r.width, r.height) * 0.002), ctx)
            rimLight(path, r, width: max(1, min(r.width, r.height) * 0.004), strength: 0.35, ctx)
        }
    }

    /// Paper fibres: a very light noise, so print looks printed.
    private static func paperGrain(_ path: CGPath, _ r: CGRect, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        var rng = SeededRandom(seed: 42)
        let count = Int(min(4000, r.width * r.height / 180))
        for _ in 0..<count {
            let x = r.minX + rng.next() * r.width, y = r.minY + rng.next() * r.height
            ctx.setFillColor(rng.next() > 0.5 ? gray(0, 0.025) : gray(1, 0.05))
            let s = max(1, r.width * 0.0025)
            ctx.fill(CGRect(x: x, y: y, width: s, height: s))
        }
        ctx.restoreGState()
    }

    private static func drawPaper(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool,
                                  corner: CGFloat, tape: Bool) {
        let radius = min(r.width, r.height) * corner
        let path = rounded(r, radius)
        ctx.setFillColor(f.surface.cgColor)
        ctx.addPath(path); ctx.fillPath()
        drawScreen(screen, in: r, radius: radius, ctx: ctx, turned: turned, glass: false)
        // Light from the top left and a slight curl: brighter near the top, a soft fold of shade at the bottom.
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        if let g = gradient([gray(1, 0.14), gray(1, 0), gray(0, 0), gray(0, 0.08)], [0, 0.4, 0.75, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
        }
        if let g = gradient([gray(0, 0.06), gray(0, 0)], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.minY + r.height * 0.06), options: [])
        }
        ctx.restoreGState()
        paperGrain(path, r, ctx)
        rimLight(path, r, width: max(1, min(r.width, r.height) * 0.006), strength: 0.5, ctx)
        if tape {
            for (x, angle) in [(r.minX + r.width * 0.12, 0.6), (r.maxX - r.width * 0.12, -0.6)] {
                ctx.saveGState()
                ctx.translateBy(x: x, y: r.maxY - r.height * 0.03)
                ctx.rotate(by: CGFloat(angle))
                let t = CGRect(x: -r.width * 0.07, y: -r.height * 0.016, width: r.width * 0.14, height: r.height * 0.032)
                ctx.setShadow(offset: CGSize(width: 0, height: -t.height * 0.08), blur: t.height * 0.3, color: gray(0, 0.12))
                ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.97, blue: 0.92, alpha: 0.62))
                ctx.fill(t)
                ctx.restoreGState()
            }
        }
    }

    private static func drawBook(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let pages = r.width * 0.035
        let cover = CGRect(x: r.minX, y: r.minY + pages, width: r.width - pages, height: r.height - pages)
        // Page block, visible on the right and at the bottom, with fine page lines.
        let block = CGRect(x: r.minX + pages, y: r.minY, width: r.width - pages, height: r.height - pages)
        let blockPath = rounded(block, r.width * 0.01)
        fillHorizontal(blockPath, block, [CGColor(srgbRed: 0.93, green: 0.90, blue: 0.84, alpha: 1),
                                          CGColor(srgbRed: 0.97, green: 0.95, blue: 0.90, alpha: 1)], [0, 1], ctx)
        ctx.setStrokeColor(gray(0, 0.06))
        ctx.setLineWidth(max(1, r.width * 0.0015))
        var i: CGFloat = 1
        while i < 9 {
            let inset = pages * i / 9
            ctx.move(to: CGPoint(x: block.maxX - inset, y: block.minY + pages))
            ctx.addLine(to: CGPoint(x: block.maxX - inset, y: block.maxY - pages))
            ctx.move(to: CGPoint(x: block.minX + pages, y: block.minY + inset))
            ctx.addLine(to: CGPoint(x: block.maxX - pages, y: block.minY + inset))
            i += 1
        }
        ctx.strokePath()
        // Cover with the design, the spine crease and a beveled edge.
        let coverPath = rounded(cover, r.width * 0.012)
        ctx.setFillColor(f.surface.cgColor)
        ctx.addPath(coverPath); ctx.fillPath()
        drawScreen(screen, in: cover, radius: r.width * 0.012, ctx: ctx, turned: false, glass: false)
        ctx.saveGState()
        ctx.addPath(coverPath); ctx.clip()
        if let g = gradient([gray(0, 0.38), gray(1, 0.20), gray(0, 0.14), gray(0, 0), gray(0, 0), gray(0, 0.10)],
                            [0, 0.025, 0.055, 0.11, 0.85, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: cover.minX, y: cover.midY), end: CGPoint(x: cover.maxX, y: cover.midY), options: [])
        }
        if let g = gradient([gray(1, 0.12), gray(1, 0)], [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: cover.midX, y: cover.maxY), end: CGPoint(x: cover.midX, y: cover.midY), options: [])
        }
        ctx.restoreGState()
        paperGrain(coverPath, cover, ctx)
        rimLight(coverPath, cover, width: max(1, r.width * 0.008), strength: 0.4, ctx)
    }
}
