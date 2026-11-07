import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import Mise

final class ModelTests: XCTestCase {
    func testRoundTripKeepsEverything() throws {
        var p = Project()
        p.background = .mesh([RGBA(hex: "#112233")!, RGBA(hex: "#445566")!], seed: 42)
        var item = Item(.laptop, finish: "midnight", x: 0.3, y: 0.6, size: 0.5, rotation: 12, yaw: -20, pitch: 5)
        item.screen = p.addAsset(Data([1, 2, 3]))
        p.items = [item, Item(.screenOnly)]
        p.items[1].sanitize()
        let decoded = try JSONDecoder().decode(Project.self, from: p.encoded())
        XCTAssertEqual(decoded, p)
    }

    func testSanitizeClampsEverything() throws {
        let json = """
        {"version":1,"width":999999,"height":-5,"background":{"solid":{"_0":"#FF0000"}},
         "items":[{"id":"\(UUID().uuidString)","kind":"phone","finish":"unknown","x":1e9,"y":-1e9,"size":0,
                   "rotation":720,"yaw":400,"pitch":-400,"landscape":false,"shadow":7,"reflection":false}],
         "assets":{"orphan":"AQID"}}
        """
        let p = try Project.decode(Data(json.utf8))
        XCTAssertEqual(p.width, Project.maxSide)
        XCTAssertEqual(p.height, 64)
        let i = p.items[0]
        XCTAssertEqual(i.x, 1.5); XCTAssertEqual(i.y, -0.5); XCTAssertEqual(i.size, 0.05)
        XCTAssertEqual(i.rotation, 180); XCTAssertEqual(i.yaw, 60); XCTAssertEqual(i.pitch, -60); XCTAssertEqual(i.shadow, 1)
        XCTAssertEqual(i.finish, "graphite")
        XCTAssertTrue(p.assets.isEmpty, "unused images are dropped")
    }

    func testBackgroundColorListsAreBounded() {
        var p = Project()
        p.background = .gradient(Array(repeating: .white, count: 5000), angle: .infinity)
        p.sanitize()
        guard case .gradient(let colors, let angle) = p.background else { return XCTFail() }
        XCTAssertEqual(colors.count, 8)
        XCTAssertTrue(angle.isFinite)
        p.background = .mesh([], seed: .max)
        p.sanitize()
        guard case .mesh(let mesh, _) = p.background else { return XCTFail() }
        XCTAssertGreaterThanOrEqual(mesh.count, 2)
    }

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try Project.decode(Data("not json".utf8)))
        XCTAssertNil(ProjectStore.normalizedImageData(Data("hello".utf8)))
    }

    func testHexColors() {
        XCTAssertEqual(RGBA(hex: "#FF8000")?.hex, "#FF8000")
        XCTAssertEqual(RGBA(hex: "#FF800080")?.hex, "#FF800080")
        XCTAssertNil(RGBA(hex: "#XYZ"))
    }

    @MainActor func testWebAddresses() {
        XCTAssertEqual(WebCapture.normalizedURL("example.com")?.absoluteString, "https://example.com")
        XCTAssertNotNil(WebCapture.normalizedURL("http://localhost:8080/page"))
        XCTAssertNil(WebCapture.normalizedURL("file:///etc/passwd"))
        XCTAssertNil(WebCapture.normalizedURL("javascript:alert(1)"))
        XCTAssertNil(WebCapture.normalizedURL("   "))
    }
}

final class GeometryTests: XCTestCase {
    func testFlatProjectionIsTheRectangle() {
        let c = Projection.corners(width: 200, height: 100, yaw: 0, pitch: 0, rotation: 0, center: CGPoint(x: 500, y: 300))
        XCTAssertEqual(c, [CGPoint(x: 400, y: 350), CGPoint(x: 600, y: 350), CGPoint(x: 600, y: 250), CGPoint(x: 400, y: 250)])
    }

    func testYawShrinksTheFarSide() {
        let c = Projection.corners(width: 200, height: 200, yaw: 30, pitch: 0, rotation: 0, center: .zero)
        let left = c[0].y - c[3].y, right = c[1].y - c[2].y
        XCTAssertGreaterThan(left, right, "positive yaw turns the right side away")
    }

    func testRotationKeepsTheCenter() {
        let c = Projection.corners(width: 100, height: 60, yaw: 0, pitch: 0, rotation: 37, center: CGPoint(x: 10, y: 20))
        let cx = c.map(\.x).reduce(0, +) / 4, cy = c.map(\.y).reduce(0, +) / 4
        XCTAssertEqual(cx, 10, accuracy: 1e-9)
        XCTAssertEqual(cy, 20, accuracy: 1e-9)
    }
}

final class RenderTests: XCTestCase {
    private func coverage(_ image: CGImage) -> Double {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let px = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        var opaque = 0
        for i in 0..<(image.width * image.height) where px[i * 4 + 3] > 10 { opaque += 1 }
        return Double(opaque) / Double(image.width * image.height)
    }

    func testEveryDeviceAndFinishRenders() {
        for kind in DeviceKind.allCases {
            for finish in Finish.all(for: kind) {
                for landscape in [false, true] {
                    guard let image = DeviceRenderer.render(kind, finish: finish, screen: nil, height: 300, landscape: landscape) else {
                        return XCTFail("\(kind) \(finish.id)")
                    }
                    let turned = landscape && DeviceRenderer.canRotate(kind)
                    XCTAssertEqual(turned ? image.width : image.height, 300, "\(kind)")
                    XCTAssertGreaterThan(coverage(image), 0.3, "\(kind) \(finish.id) draws something")
                }
            }
        }
    }

    @MainActor func testTemplatesAreUniqueAndValid() {
        let all = Template.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertGreaterThanOrEqual(all.count, 30)
        for template in all {
            var p = template.make()
            let before = p.items.count
            p.sanitize()
            XCTAssertEqual(p.items.count, before, template.id)
            XCTAssertFalse(template.title.isEmpty, template.id)
        }
    }

    @MainActor func testEveryTemplateRendersAtTheRightSize() {
        for template in Template.all {
            let p = template.make()
            guard let image = Renderer.shared.render(p, scale: 0.25) else { return XCTFail(template.id) }
            XCTAssertEqual(image.width, Int((Double(p.width) * 0.25).rounded()), template.id)
            XCTAssertEqual(image.height, Int((Double(p.height) * 0.25).rounded()), template.id)
        }
    }

    func testTransparentBackgroundStaysTransparent() {
        var p = Project()
        p.background = .transparent
        p.items = []
        let image = Renderer.shared.render(p, scale: 0.1)!
        XCTAssertEqual(coverage(image), 0)
    }

    func testEncoders() {
        var p = Project()
        p.items = [Item(.phone)]
        let image = Renderer.shared.render(p, scale: 0.2)!
        XCTAssertEqual(Exporter.encode(image, format: .png)?.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertEqual(Exporter.encode(image, format: .jpeg)?.prefix(2), Data([0xFF, 0xD8]))
        XCTAssertNotNil(Exporter.encode(image, format: .heic))
    }

    func testExportScaleLimit() {
        var p = Project()
        p.width = 8000
        p.height = 4000
        XCTAssertEqual(Exporter.maxScale(for: p), 2)
    }
}

/// Renders every template and device to JPEG files when PREVIEW_DIR is set (used by CI to look at them).
final class PreviewTests: XCTestCase {
    @MainActor func testWritePreviews() throws {
        guard let dir = ProcessInfo.processInfo.environment["PREVIEW_DIR"] else { throw XCTSkip("PREVIEW_DIR not set") }
        for template in Template.all {
            let p = template.make()
            let image = Renderer.shared.render(p, scale: 640 / CGFloat(max(p.width, p.height)))!
            try Exporter.encode(image, format: .jpeg, quality: 0.8)!.write(to: URL(fileURLWithPath: "\(dir)/t-\(template.id).jpg"))
        }
        var sheet = Project()
        sheet.width = 1800
        sheet.height = 900
        sheet.background = .solid(RGBA(hex: "#EEEEF2")!)
        let kinds = DeviceKind.allCases.filter { $0 != .screenOnly }
        for (i, kind) in kinds.enumerated() {
            let col = i % 6, row = i / 6
            sheet.items.append(Item(kind, x: (Double(col) + 0.5) / 6, y: (Double(row) + 0.5) / 2, size: kind == .laptop || kind == .desktop || kind == .browser || kind == .businessCard ? 0.16 : 0.38, shadow: 0.4))
        }
        let image = Renderer.shared.render(sheet, scale: 1)!
        try Exporter.encode(image, format: .jpeg, quality: 0.85)!.write(to: URL(fileURLWithPath: "\(dir)/devices.jpg"))
    }
}
