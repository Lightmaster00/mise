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
        case .businessCard: drawPaper(r, finish, screen, ctx, contentTurned, corner: 0.03, tape: false)
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

    /// Polished metal edge: a horizontal gradient light in the middle and dark at the sides.
    private static func fillMetal(_ path: CGPath, _ r: CGRect, _ f: Finish, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let (dark, light, mid) = f.edge
        let colors = [dark, light, mid, mid, light, dark].map(\.cgColor) as CFArray
        if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 0.035, 0.12, 0.88, 0.965, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.midY), end: CGPoint(x: r.maxX, y: r.midY), options: [])
        }
        ctx.restoreGState()
    }

    private static func fillVertical(_ path: CGPath, _ r: CGRect, top: RGBA, bottom: RGBA, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let g = CGGradient(colorsSpace: nil, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        }
        ctx.restoreGState()
    }

    /// Draws the design aspect-filled into a rounded screen, then a soft glass reflection.
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
        if glass {
            ctx.saveGState()
            ctx.addPath(rounded(r, radius))
            ctx.clip()
            let colors = [RGBA(1, 1, 1, 0.10).cgColor, RGBA(1, 1, 1, 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY),
                                       end: CGPoint(x: r.midX, y: r.midY), options: [])
            }
            ctx.restoreGState()
        }
    }

    static func aspectFill(_ image: CGImage, _ r: CGRect) -> CGRect {
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        guard iw > 0, ih > 0 else { return r }
        let scale = max(r.width / iw, r.height / ih)
        let w = iw * scale, h = ih * scale
        // Align to the top: screenshots are read from the top.
        return CGRect(x: r.midX - w / 2, y: r.maxY - h, width: w, height: h)
    }

    /// A pleasant generic app screen, used until a design is dropped.
    static func drawPlaceholder(in r: CGRect, ctx: CGContext, turned: Bool) {
        let colors = [RGBA(hex: "#6E5BFF")!.cgColor, RGBA(hex: "#FF7AA8")!.cgColor] as CFArray
        if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
        }
        let unit = min(r.width, r.height)
        ctx.setFillColor(RGBA(1, 1, 1, 0.9).cgColor)
        let pad = unit * 0.09
        // Title bar, a card and a few lines.
        let title = CGRect(x: r.minX + pad, y: r.maxY - pad * 2.2, width: r.width * 0.45, height: unit * 0.05)
        ctx.addPath(rounded(title, title.height / 2)); ctx.fillPath()
        let card = CGRect(x: r.minX + pad, y: r.maxY - pad * 2.8 - r.height * 0.28, width: r.width - pad * 2, height: r.height * 0.28)
        ctx.setFillColor(RGBA(1, 1, 1, 0.28).cgColor)
        ctx.addPath(rounded(card, unit * 0.05)); ctx.fillPath()
        ctx.setFillColor(RGBA(1, 1, 1, 0.55).cgColor)
        var y = card.minY - pad
        for i in 0..<4 {
            let line = CGRect(x: r.minX + pad, y: y - unit * 0.035, width: (r.width - pad * 2) * [0.9, 0.7, 0.8, 0.5][i], height: unit * 0.035)
            ctx.addPath(rounded(line, line.height / 2)); ctx.fillPath()
            y -= unit * 0.08
            if y < r.minY + pad { break }
        }
    }

    private static func drawPhone(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool, android: Bool) {
        let W = r.width
        // Side buttons, behind the body.
        ctx.setFillColor(f.edge.0.cgColor)
        let bw = W * 0.012
        for (y, len) in (android ? [(0.70, 0.10), (0.56, 0.06)] : [(0.78, 0.035), (0.70, 0.07), (0.60, 0.07)]) {
            let side = android ? r.maxX - bw * 0.2 : r.minX - bw * 0.8
            ctx.addPath(rounded(CGRect(x: side, y: r.minY + r.height * y - r.height * len / 2, width: bw, height: r.height * len), bw / 2))
            ctx.fillPath()
        }
        if !android {
            ctx.addPath(rounded(CGRect(x: r.maxX - bw * 0.2, y: r.minY + r.height * 0.66, width: bw, height: r.height * 0.11), bw / 2))
            ctx.fillPath()
        }
        let body = r.insetBy(dx: W * 0.006, dy: W * 0.006)
        let radius = W * (android ? 0.11 : 0.165)
        fillMetal(rounded(body, radius), body, f, ctx)
        // Black glass around the screen.
        let glass = body.insetBy(dx: W * 0.018, dy: W * 0.018)
        ctx.setFillColor(RGBA(0.02, 0.02, 0.03).cgColor)
        ctx.addPath(rounded(glass, radius - W * 0.018)); ctx.fillPath()
        let s = glass.insetBy(dx: W * 0.028, dy: W * 0.028)
        drawScreen(screen, in: s, radius: radius - W * 0.046, ctx: ctx, turned: turned)
        // Camera: a pill (island) or a punch hole.
        ctx.setFillColor(RGBA(0, 0, 0).cgColor)
        if android {
            let d = W * 0.045
            ctx.fillEllipse(in: CGRect(x: s.midX - d / 2, y: s.maxY - W * 0.045 - d, width: d, height: d))
        } else {
            let pill = CGRect(x: s.midX - W * 0.15, y: s.maxY - W * 0.035 - W * 0.085, width: W * 0.30, height: W * 0.085)
            ctx.addPath(rounded(pill, pill.height / 2)); ctx.fillPath()
        }
    }

    private static func drawTablet(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool) {
        let W = r.width
        let body = r.insetBy(dx: W * 0.004, dy: W * 0.004)
        let radius = W * 0.075
        fillMetal(rounded(body, radius), body, f, ctx)
        let glass = body.insetBy(dx: W * 0.012, dy: W * 0.012)
        ctx.setFillColor(RGBA(0.02, 0.02, 0.03).cgColor)
        ctx.addPath(rounded(glass, radius - W * 0.012)); ctx.fillPath()
        let s = glass.insetBy(dx: W * 0.045, dy: W * 0.045)
        drawScreen(screen, in: s, radius: W * 0.03, ctx: ctx, turned: turned)
        ctx.setFillColor(RGBA(0.12, 0.12, 0.14).cgColor)
        let d = W * 0.014
        ctx.fillEllipse(in: CGRect(x: glass.midX - d / 2, y: glass.maxY - W * 0.0225 - d / 2, width: d, height: d))
    }

    private static func drawLaptop(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let total = r.width
        let L = total / 1.14
        let baseH = L * 0.04
        let lid = CGRect(x: r.midX - L / 2, y: r.minY + baseH * 0.6, width: L, height: r.height - baseH * 0.6)
        // Lid: thin colored edge, black bezel, screen.
        fillMetal(rounded(lid, L * 0.03), lid, f, ctx)
        let bezel = lid.insetBy(dx: L * 0.006, dy: L * 0.006)
        ctx.setFillColor(RGBA(0.03, 0.03, 0.04).cgColor)
        ctx.addPath(rounded(bezel, L * 0.026)); ctx.fillPath()
        let s = CGRect(x: bezel.minX + L * 0.018, y: bezel.minY + L * 0.03, width: bezel.width - L * 0.036,
                       height: bezel.height - L * 0.048)
        drawScreen(screen, in: s, radius: L * 0.008, ctx: ctx, turned: false)
        // Base: wider, with rounded front corners and a thumb notch.
        let base = CGPath(roundedRect: CGRect(x: r.minX, y: r.minY, width: total, height: baseH),
                          cornerWidth: baseH * 0.9, cornerHeight: baseH * 0.5, transform: nil)
        fillVertical(base, r, top: f.edge.1, bottom: f.edge.0, ctx)
        let notch = CGRect(x: r.midX - L * 0.08, y: r.minY + baseH * 0.45, width: L * 0.16, height: baseH * 0.55)
        ctx.setFillColor(f.edge.2.cgColor)
        ctx.addPath(rounded(notch, notch.height / 2)); ctx.fillPath()
    }

    private static func drawDesktop(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let D = r.width
        let displayH = D * 0.5925
        let display = CGRect(x: r.minX, y: r.maxY - displayH, width: D, height: displayH)
        // Stand: neck and foot.
        let neck = CGRect(x: r.midX - D * 0.09, y: r.minY + D * 0.02, width: D * 0.18, height: r.height - displayH)
        fillVertical(rounded(neck, D * 0.01), neck, top: f.edge.0, bottom: f.edge.2, ctx)
        let foot = CGRect(x: r.midX - D * 0.16, y: r.minY, width: D * 0.32, height: D * 0.03)
        fillVertical(rounded(foot, D * 0.012), foot, top: f.edge.1, bottom: f.edge.0, ctx)
        fillMetal(rounded(display, D * 0.018), display, f, ctx)
        let bezel = display.insetBy(dx: D * 0.005, dy: D * 0.005)
        ctx.setFillColor(RGBA(0.03, 0.03, 0.04).cgColor)
        ctx.addPath(rounded(bezel, D * 0.014)); ctx.fillPath()
        drawScreen(screen, in: bezel.insetBy(dx: D * 0.013, dy: D * 0.013), radius: D * 0.004, ctx: ctx, turned: false)
    }

    private static func drawWatch(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let C = r.height / 2.0          // case height
        let cw = C * 0.83
        let caseRect = CGRect(x: r.midX - cw / 2, y: r.midY - C / 2, width: cw, height: C)
        // Band, fading out at both ends.
        let band = CGRect(x: r.midX - cw * 0.38, y: r.minY, width: cw * 0.76, height: r.height)
        ctx.saveGState()
        ctx.addPath(rounded(band, cw * 0.12)); ctx.clip()
        let bc = f.surface
        let colors = [RGBA(bc.r, bc.g, bc.b, 0).cgColor, bc.cgColor, bc.cgColor, RGBA(bc.r, bc.g, bc.b, 0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 0.2, 0.8, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        }
        ctx.restoreGState()
        // Crown.
        ctx.setFillColor(f.edge.2.cgColor)
        ctx.addPath(rounded(CGRect(x: caseRect.maxX - cw * 0.02, y: caseRect.midY + C * 0.08, width: cw * 0.07, height: C * 0.16), cw * 0.02))
        ctx.fillPath()
        fillMetal(rounded(caseRect, cw * 0.24), caseRect, f, ctx)
        let glass = caseRect.insetBy(dx: cw * 0.035, dy: cw * 0.035)
        ctx.setFillColor(RGBA(0, 0, 0).cgColor)
        ctx.addPath(rounded(glass, cw * 0.21)); ctx.fillPath()
        drawScreen(screen, in: glass.insetBy(dx: cw * 0.06, dy: cw * 0.06), radius: cw * 0.15, ctx: ctx, turned: false)
    }

    private static func drawBrowser(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let W = r.width
        let dark = f.id == "dark"
        let window = rounded(r, W * 0.012)
        ctx.saveGState()
        ctx.addPath(window); ctx.clip()
        let barH = W * 0.06
        let bar = CGRect(x: r.minX, y: r.maxY - barH, width: W, height: barH)
        ctx.setFillColor((dark ? RGBA(hex: "#2B2B2F")! : RGBA(hex: "#ECECEF")!).cgColor)
        ctx.fill(bar)
        let content = CGRect(x: r.minX, y: r.minY, width: W, height: r.height - barH)
        drawScreen(screen, in: content, radius: 0, ctx: ctx, turned: false, glass: false)
        ctx.restoreGState()
        // Traffic lights.
        let d = barH * 0.26
        for (i, hex) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
            ctx.setFillColor(RGBA(hex: hex)!.cgColor)
            ctx.fillEllipse(in: CGRect(x: r.minX + barH * 0.42 + CGFloat(i) * d * 1.7, y: bar.midY - d / 2, width: d, height: d))
        }
        // Address field.
        let field = CGRect(x: r.midX - W * 0.2, y: bar.midY - barH * 0.22, width: W * 0.4, height: barH * 0.44)
        ctx.setFillColor((dark ? RGBA(hex: "#3A3A3F")! : RGBA(1, 1, 1)).cgColor)
        ctx.addPath(rounded(field, field.height / 2)); ctx.fillPath()
        ctx.setFillColor((dark ? RGBA(1, 1, 1, 0.35) : RGBA(0, 0, 0, 0.25)).cgColor)
        let text = CGRect(x: field.midX - field.width * 0.22, y: field.midY - field.height * 0.12, width: field.width * 0.44, height: field.height * 0.24)
        ctx.addPath(rounded(text, text.height / 2)); ctx.fillPath()
        // Hairline border.
        ctx.setStrokeColor((dark ? RGBA(1, 1, 1, 0.12) : RGBA(0, 0, 0, 0.12)).cgColor)
        ctx.setLineWidth(max(1, W * 0.0008))
        ctx.addPath(window); ctx.strokePath()
    }

    private static func drawFloating(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let radius = f.id == "none" ? 0 : min(r.width, r.height) * 0.04
        drawScreen(screen, in: r, radius: radius, ctx: ctx, turned: false, glass: false)
        if f.id != "none" {
            ctx.setStrokeColor((f.id == "dark" ? RGBA(1, 1, 1, 0.15) : RGBA(0, 0, 0, 0.1)).cgColor)
            ctx.setLineWidth(max(1, min(r.width, r.height) * 0.002))
            ctx.addPath(rounded(r.insetBy(dx: 0.5, dy: 0.5), radius)); ctx.strokePath()
        }
    }

    private static func drawPaper(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext, _ turned: Bool,
                                  corner: CGFloat, tape: Bool) {
        let radius = min(r.width, r.height) * corner
        ctx.setFillColor(f.surface.cgColor)
        ctx.addPath(rounded(r, radius)); ctx.fillPath()
        drawScreen(screen, in: r, radius: radius, ctx: ctx, turned: turned, glass: false)
        // Paper: a soft shading from the top left.
        ctx.saveGState()
        ctx.addPath(rounded(r, radius)); ctx.clip()
        let colors = [RGBA(1, 1, 1, 0.12).cgColor, RGBA(0, 0, 0, 0.06).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
        }
        ctx.restoreGState()
        if tape {
            ctx.setFillColor(RGBA(1, 1, 1, 0.55).cgColor)
            for (x, angle) in [(r.minX + r.width * 0.12, 0.6), (r.maxX - r.width * 0.12, -0.6)] {
                ctx.saveGState()
                ctx.translateBy(x: x, y: r.maxY - r.height * 0.03)
                ctx.rotate(by: CGFloat(angle))
                ctx.fill(CGRect(x: -r.width * 0.07, y: -r.height * 0.016, width: r.width * 0.14, height: r.height * 0.032))
                ctx.restoreGState()
            }
        }
    }

    private static func drawBook(_ r: CGRect, _ f: Finish, _ screen: CGImage?, _ ctx: CGContext) {
        let pages = r.width * 0.035
        let cover = CGRect(x: r.minX, y: r.minY + pages, width: r.width - pages, height: r.height - pages)
        // Page block, visible on the right and at the bottom.
        let block = CGRect(x: r.minX + pages, y: r.minY, width: r.width - pages, height: r.height - pages)
        ctx.setFillColor(RGBA(hex: "#F3EEE3")!.cgColor)
        ctx.addPath(rounded(block, r.width * 0.01)); ctx.fillPath()
        ctx.setStrokeColor(RGBA(0, 0, 0, 0.07).cgColor)
        ctx.setLineWidth(max(1, r.width * 0.002))
        var i: CGFloat = 1
        while i < 6 {
            let inset = pages * i / 6
            ctx.move(to: CGPoint(x: block.maxX - inset, y: block.minY + pages))
            ctx.addLine(to: CGPoint(x: block.maxX - inset, y: block.maxY - pages))
            i += 1
        }
        ctx.strokePath()
        // Cover with the design, then the spine shading.
        ctx.setFillColor(f.surface.cgColor)
        ctx.addPath(rounded(cover, r.width * 0.012)); ctx.fillPath()
        drawScreen(screen, in: cover, radius: r.width * 0.012, ctx: ctx, turned: false, glass: false)
        ctx.saveGState()
        ctx.addPath(rounded(cover, r.width * 0.012)); ctx.clip()
        let colors = [RGBA(0, 0, 0, 0.35).cgColor, RGBA(1, 1, 1, 0.18).cgColor, RGBA(0, 0, 0, 0.12).cgColor, RGBA(0, 0, 0, 0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 0.03, 0.06, 0.12]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: cover.minX, y: cover.midY), end: CGPoint(x: cover.maxX, y: cover.midY), options: [])
        }
        ctx.restoreGState()
    }
}
