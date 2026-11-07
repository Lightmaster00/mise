import AppKit
import SwiftUI

@main
struct MiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = ProjectStore.shared

    var body: some Scene {
        Window("Mise", id: "main") {
            ContentView()
                .frame(minWidth: 940, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(S.new) { store.newProject() }.keyboardShortcut("n")
                Button(S.openEllipsis) { store.open() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button(S.save) { store.save() }.keyboardShortcut("s")
                Button(S.saveAs) { store.save(as: true) }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .importExport) {
                Button(S.importDesignEllipsis) { store.importDesign() }.keyboardShortcut("i")
                Button(S.captureWebsiteEllipsis) { NotificationCenter.default.post(name: .miseShowCapture, object: nil) }
                    .keyboardShortcut("l")
                Divider()
                Button(S.exportEllipsis) { ExportSettings.shared.exportNow() }.keyboardShortcut("e")
                Button(S.batchExport) { ExportSettings.shared.batch() }.keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button(S.undo) { store.undo() }.keyboardShortcut("z").disabled(!store.canUndo)
                Button(S.redo) { store.redo() }.keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!store.canRedo)
            }
            CommandGroup(replacing: .pasteboard) {
                Button(S.copyImage) { Exporter.copy(store.project) }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button(S.pasteDesign) { store.pasteDesign() }.keyboardShortcut("v")
                Button(S.duplicate) { store.duplicateSelected() }.keyboardShortcut("d")
                Button(S.delete) { store.deleteSelected() }.keyboardShortcut(.delete, modifiers: [])
            }
            CommandGroup(after: .appInfo) {
                Button(S.checkForUpdates) { Updater.checkNow() }.disabled(!Updater.isConfigured)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Updater.startAutomaticChecks()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "mise" }),
              ProjectStore.shared.confirmDiscard() else { return }
        ProjectStore.shared.open(url)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ProjectStore.shared.confirmDiscard() ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum PrefKey {
    static let skippedVersion = "updates.skippedVersion"
}

enum Prefs {
    static var autoCheckUpdates: Bool {
        get { UserDefaults.standard.object(forKey: "updates.autoCheck") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "updates.autoCheck") }
    }
}
