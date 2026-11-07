import Foundation

/// Ready-made compositions to start from.
struct Template: Identifiable {
    let id: String
    let title: String
    let make: () -> Project

    private static func hex(_ s: String) -> RGBA { RGBA(hex: s)! }

    private static func project(_ w: Int, _ h: Int, _ bg: Background, _ items: [Item]) -> Project {
        var p = Project()
        p.width = w
        p.height = h
        p.background = bg
        p.items = items
        return p
    }

    static let lavender: Background = .gradient([hex("#EDE9FF"), hex("#FFE4EE")], angle: 135)
    static let dusk: Background = .mesh([hex("#1B1640"), hex("#6E5BFF"), hex("#FF7AA8"), hex("#3B2E8F")], seed: 11)
    static let sand: Background = .texture(.grain, hex("#EFE8DE"))
    static let mint: Background = .gradient([hex("#D9F7EE"), hex("#E8F0FF")], angle: 160)
    static let graphite: Background = .mesh([hex("#15161B"), hex("#2F3340"), hex("#3A3F55"), hex("#1E2230")], seed: 5)
    static let peach: Background = .mesh([hex("#FFE9DD"), hex("#FFC6B0"), hex("#FFD9A8"), hex("#F7B7C8")], seed: 3)
    static let paper: Background = .texture(.dots, hex("#F5F4F0"))
    static let sky: Background = .gradient([hex("#4F7BFF"), hex("#9B6BFF")], angle: 120)

    static var all: [Template] {
        [
            Template(id: "phone", title: S.tplPhone) {
                project(1600, 1200, lavender, [Item(.phone, size: 0.78)])
            },
            Template(id: "phoneTilted", title: S.tplPhoneTilted) {
                project(1600, 1200, dusk, [Item(.phone, finish: "silver", size: 0.8, rotation: -8, yaw: -22, pitch: 8, shadow: 0.8)])
            },
            Template(id: "threePhones", title: S.tplThreePhones) {
                project(1920, 1080, peach, [
                    Item(.phone, finish: "white", x: 0.3, y: 0.55, size: 0.7, rotation: -6),
                    Item(.phone, finish: "white", x: 0.7, y: 0.55, size: 0.7, rotation: 6),
                    Item(.phone, finish: "white", x: 0.5, y: 0.5, size: 0.8),
                ])
            },
            Template(id: "laptopPhone", title: S.tplLaptopPhone) {
                project(1920, 1080, mint, [
                    Item(.laptop, finish: "silver", x: 0.46, y: 0.5, size: 0.7),
                    Item(.phone, finish: "silver", x: 0.8, y: 0.6, size: 0.5),
                ])
            },
            Template(id: "laptop", title: S.tplLaptop) {
                project(1600, 1200, sand, [Item(.laptop, finish: "spacegray", size: 0.62)])
            },
            Template(id: "laptopAngle", title: S.tplLaptopAngle) {
                project(1600, 1200, graphite, [Item(.laptop, finish: "midnight", size: 0.6, yaw: 24, pitch: 6, shadow: 0.9)])
            },
            Template(id: "desktop", title: S.tplDesktop) {
                project(1920, 1080, paper, [Item(.desktop, finish: "silver", size: 0.82)])
            },
            Template(id: "tabletPhone", title: S.tplTabletPhone) {
                project(1600, 1200, lavender, [
                    Item(.tablet, finish: "silver", x: 0.44, y: 0.5, size: 0.8),
                    Item(.phone, finish: "silver", x: 0.76, y: 0.58, size: 0.62),
                ])
            },
            Template(id: "watch", title: S.tplWatch) {
                project(1080, 1080, peach, [Item(.watch, finish: "midnight", size: 0.95)])
            },
            Template(id: "browser", title: S.tplBrowser) {
                project(1920, 1200, sky, [Item(.browser, finish: "light", size: 0.72, shadow: 0.7)])
            },
            Template(id: "floating", title: S.tplFloating) {
                project(1600, 1200, mint, [Item(.floating, finish: "light", size: 0.7, yaw: 18, pitch: 10, shadow: 0.7)])
            },
            Template(id: "card", title: S.tplCard) {
                project(1600, 1200, sand, [Item(.businessCard, finish: "paper", size: 0.42, rotation: -8, shadow: 0.6)])
            },
            Template(id: "poster", title: S.tplPoster) {
                project(1200, 1500, .texture(.linen, hex("#E9E4DA")), [Item(.poster, finish: "paper", size: 0.8, shadow: 0.5)])
            },
            Template(id: "book", title: S.tplBook) {
                project(1600, 1200, .texture(.grain, hex("#E5DED3")), [Item(.book, finish: "cloth", size: 0.72, rotation: 4, yaw: -14, shadow: 0.8)])
            },
            Template(id: "story", title: S.tplStory) {
                project(1080, 1920, dusk, [Item(.phone, finish: "graphite", size: 0.78)])
            },
            Template(id: "square", title: S.tplSquare) {
                project(1080, 1080, lavender, [Item(.phone, finish: "blue", size: 0.84, rotation: -10, shadow: 0.7)])
            },
            Template(id: "android", title: S.tplAndroid) {
                project(1600, 1200, sky, [Item(.phoneAndroid, finish: "white", size: 0.78, shadow: 0.7)])
            },
            Template(id: "twoPhones", title: S.tplTwoPhones) {
                project(1600, 1200, mint, [
                    Item(.phone, finish: "graphite", x: 0.37, y: 0.52, size: 0.76, rotation: -4),
                    Item(.phoneAndroid, finish: "graphite", x: 0.63, y: 0.48, size: 0.76, rotation: 4),
                ])
            },
            Template(id: "fan", title: S.tplFan) {
                project(1920, 1080, sky, [
                    Item(.phone, finish: "white", x: 0.18, y: 0.56, size: 0.6, rotation: -10, yaw: -18),
                    Item(.phone, finish: "white", x: 0.34, y: 0.53, size: 0.66, rotation: -5, yaw: -9),
                    Item(.phone, finish: "white", x: 0.66, y: 0.53, size: 0.66, rotation: 5, yaw: 9),
                    Item(.phone, finish: "white", x: 0.82, y: 0.56, size: 0.6, rotation: 10, yaw: 18),
                    Item(.phone, finish: "white", x: 0.5, y: 0.5, size: 0.74),
                ])
            },
            Template(id: "reflection", title: S.tplReflection) {
                var item = Item(.phone, finish: "graphite", y: 0.42, size: 0.62, shadow: 0.4)
                item.reflection = true
                return project(1600, 1200, graphite, [item])
            },
            Template(id: "flatLay", title: S.tplFlatLay) {
                project(1600, 1200, peach, [
                    Item(.phone, finish: "gold", x: 0.36, y: 0.5, size: 0.72, rotation: -14, pitch: 28, shadow: 0.7),
                    Item(.phone, finish: "gold", x: 0.64, y: 0.5, size: 0.72, rotation: 14, pitch: 28, shadow: 0.7),
                ])
            },
            Template(id: "tabletLandscape", title: S.tplTabletLandscape) {
                var item = Item(.tablet, finish: "spacegray", size: 0.66, shadow: 0.7)
                item.landscape = true
                return project(1600, 1200, lavender, [item])
            },
            Template(id: "tabletAngle", title: S.tplTabletAngle) {
                project(1600, 1200, dusk, [Item(.tablet, finish: "silver", size: 0.78, rotation: 6, yaw: -20, pitch: 8, shadow: 0.9)])
            },
            Template(id: "watchPhone", title: S.tplWatchPhone) {
                project(1600, 1200, sand, [
                    Item(.phone, finish: "silver", x: 0.4, y: 0.5, size: 0.76),
                    Item(.watch, finish: "silver", x: 0.68, y: 0.56, size: 0.52),
                ])
            },
            Template(id: "ecosystem", title: S.tplEcosystem) {
                project(1920, 1080, paper, [
                    Item(.desktop, finish: "silver", x: 0.4, y: 0.47, size: 0.7),
                    Item(.laptop, finish: "silver", x: 0.7, y: 0.66, size: 0.42),
                    Item(.phone, finish: "silver", x: 0.88, y: 0.66, size: 0.36),
                ])
            },
            Template(id: "responsive", title: S.tplResponsive) {
                project(1920, 1200, lavender, [
                    Item(.browser, finish: "light", x: 0.44, y: 0.48, size: 0.68, shadow: 0.6),
                    Item(.phone, finish: "graphite", x: 0.8, y: 0.6, size: 0.56),
                ])
            },
            Template(id: "banner", title: S.tplBanner) {
                project(1500, 500, sky, [
                    Item(.laptop, finish: "spacegray", x: 0.42, y: 0.56, size: 0.82),
                    Item(.phone, finish: "graphite", x: 0.66, y: 0.6, size: 0.7),
                ])
            },
            Template(id: "appStore", title: S.tplAppStore) {
                project(1290, 2796, mint, [Item(.phone, finish: "white", y: 0.6, size: 0.72, shadow: 0.6)])
            },
            Template(id: "letter", title: S.tplLetter) {
                project(1600, 1200, .texture(.grain, hex("#E4DDD2")), [Item(.paper, finish: "paper", size: 0.86, rotation: -3, shadow: 0.5)])
            },
            Template(id: "stationery", title: S.tplStationery) {
                project(1920, 1080, .texture(.linen, hex("#E9E4DA")), [
                    Item(.paper, finish: "paper", x: 0.36, y: 0.5, size: 0.82, rotation: -4, shadow: 0.5),
                    Item(.book, finish: "cloth", x: 0.68, y: 0.48, size: 0.62, rotation: 6, shadow: 0.7),
                    Item(.businessCard, finish: "kraft", x: 0.82, y: 0.78, size: 0.26, rotation: -12, shadow: 0.6),
                ])
            },
            Template(id: "photo", title: S.tplPhoto) {
                var p = project(1600, 1200, .solid(hex("#DDDDDD")), [Item(.screenOnly, finish: "none")])
                p.sanitize()
                return p
            },
        ]
    }
}
