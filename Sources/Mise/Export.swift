import AppKit
import ImageIO
import UniformTypeIdentifiers
import WebKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case png, jpeg, heic
    var id: String { rawValue }
    var type: UTType { self == .png ? .png : self == .jpeg ? .jpeg : .heic }
    var ext: String { self == .jpeg ? "jpg" : rawValue }
    var title: String { rawValue.uppercased() }
}

enum Exporter {
    static func encode(_ image: CGImage, format: ExportFormat, quality: Double = 0.92) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else { return nil }
        var options: [CFString: Any] = [:]
        if format != .png { options[kCGImageDestinationLossyCompressionQuality] = quality }
        // JPEG has no transparency: put it on white.
        let img = format == .jpeg ? flatten(image) ?? image : image
        CGImageDestinationAddImage(dest, img, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    static func flatten(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }

    /// Largest scale allowed for a canvas (exports stay under 16 000 px per side).
    static func maxScale(for project: Project) -> Int {
        max(1, min(4, 16000 / max(project.width, project.height)))
    }

    /// Exports the current mockup.
    @MainActor
    static func export(_ project: Project, scale: Int, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.type]
        let base = ProjectStore.shared.fileURL?.deletingPathExtension().lastPathComponent ?? S.mockup
        panel.nameFieldStringValue = "\(base)@\(scale)x.\(format.ext)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let s = min(scale, maxScale(for: project))
        DispatchQueue.global(qos: .userInitiated).async {
            let data = Renderer.shared.render(project, scale: CGFloat(s)).flatMap { encode($0, format: format) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let data else { return showError(S.exportFailed, CocoaError(.fileWriteUnknown)) }
                    do { try data.write(to: url, options: .atomic) } catch { showError(S.exportFailed, error) }
                }
            }
        }
    }

    /// Puts the mockup on the clipboard (PNG, at 2x).
    @MainActor
    static func copy(_ project: Project) {
        let s = min(2, maxScale(for: project))
        guard let image = Renderer.shared.render(project, scale: CGFloat(s)), let png = encode(image, format: .png) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
    }

    /// The same mockup for several designs: each image goes on the selected device, one file each.
    @MainActor
    static func batch(_ project: Project, itemID: UUID?, scale: Int, format: ExportFormat) {
        let open = NSOpenPanel()
        open.allowedContentTypes = [.image]
        open.allowsMultipleSelection = true
        open.message = S.batchChooseImages
        guard open.runModal() == .OK, !open.urls.isEmpty else { return }
        let images = open.urls
        let folderPanel = NSOpenPanel()
        folderPanel.canChooseFiles = false
        folderPanel.canChooseDirectories = true
        folderPanel.canCreateDirectories = true
        folderPanel.prompt = S.exportHere
        folderPanel.message = S.batchChooseFolder
        guard folderPanel.runModal() == .OK, let folder = folderPanel.url else { return }
        guard let target = itemID ?? project.items.first?.id else { return }
        let s = min(scale, maxScale(for: project))

        DispatchQueue.global(qos: .userInitiated).async {
            var failures = 0
            for url in images {
                autoreleasepool {
                    guard let raw = try? Data(contentsOf: url), let data = ProjectStore.normalizedImageData(raw) else {
                        failures += 1
                        return
                    }
                    var p = project
                    let asset = p.addAsset(data)
                    if let i = p.items.firstIndex(where: { $0.id == target }) { p.items[i].screen = asset }
                    let name = url.deletingPathExtension().lastPathComponent + "-mockup.\(format.ext)"
                    let out = folder.appendingPathComponent(name)
                    guard let image = Renderer.shared.render(p, scale: CGFloat(s)), let encoded = encode(image, format: format),
                          (try? encoded.write(to: out, options: .atomic)) != nil else {
                        failures += 1
                        return
                    }
                }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if failures > 0 {
                        showError(S.batchFailures(failures), CocoaError(.fileWriteUnknown))
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
            }
        }
    }
}

/// Captures a web page as an image (the whole page or the first screen).
@MainActor
final class WebCapture: NSObject, WKNavigationDelegate {
    enum Width: Int, CaseIterable, Identifiable {
        case phone = 390, tablet = 820, desktop = 1440
        var id: Int { rawValue }
    }

    private var window: NSWindow?
    private var webView: WKWebView?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var fullPage = true
    private var timeout: DispatchWorkItem?
    private static var current: WebCapture?

    struct CaptureError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Only http and https addresses are loaded.
    static func normalizedURL(_ text: String) -> URL? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func capture(_ url: URL, width: Width, fullPage: Bool, completion: @escaping (Result<Data, Error>) -> Void) {
        current?.finish(.failure(CaptureError(message: S.captureCancelled)))
        let capture = WebCapture()
        current = capture
        capture.start(url, width: width, fullPage: fullPage, completion: completion)
    }

    private func start(_ url: URL, width: Width, fullPage: Bool, completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
        self.fullPage = fullPage
        let config = WKWebViewConfiguration()
        // Nothing is kept: no cookies, no cache.
        config.websiteDataStore = .nonPersistent()
        let height = width == .phone ? 844 : width == .tablet ? 1180 : 900
        let frame = CGRect(x: 0, y: 0, width: width.rawValue, height: height)
        let web = WKWebView(frame: frame, configuration: config)
        if width == .phone {
            web.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        } else if width == .tablet {
            web.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        }
        web.navigationDelegate = self
        // Web views only draw inside a window: an invisible one, off screen.
        let w = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: frame.width, height: frame.height),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.contentView = web
        w.orderBack(nil)
        window = w
        webView = web
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.finish(.failure(CaptureError(message: S.captureTimeout))) }
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25))
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            // Let fonts, images and animations settle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                MainActor.assumeIsolated { self?.snapshot() }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }

    private func snapshot() {
        guard let web = webView else { return }
        web.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)") { [weak self] value, _ in
            MainActor.assumeIsolated {
                guard let self, let web = self.webView else { return }
                let pageHeight = (value as? NSNumber)?.doubleValue ?? Double(web.frame.height)
                let height = self.fullPage ? min(max(pageHeight, Double(web.frame.height)), 12000) : Double(web.frame.height)
                web.setFrameSize(CGSize(width: web.frame.width, height: height))
                self.window?.setContentSize(CGSize(width: web.frame.width, height: height))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    MainActor.assumeIsolated {
                        let config = WKSnapshotConfiguration()
                        config.rect = CGRect(x: 0, y: 0, width: web.frame.width, height: height)
                        config.afterScreenUpdates = true
                        web.takeSnapshot(with: config) { image, error in
                            MainActor.assumeIsolated {
                                guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                                      let data = Exporter.encode(cg, format: .png) else {
                                    return self.finish(.failure(error ?? CaptureError(message: S.captureFailed)))
                                }
                                self.finish(.success(data))
                            }
                        }
                    }
                }
            }
        }
    }

    private func finish(_ result: Result<Data, Error>) {
        timeout?.cancel()
        timeout = nil
        guard let completion else { return }
        self.completion = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        window?.orderOut(nil)
        window = nil
        webView = nil
        if WebCapture.current === self { WebCapture.current = nil }
        completion(result)
    }
}
