import SwiftUI
import AppKit

@main
struct TimelineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Cormorant.registerFonts()
    }

    var body: some Scene {
        Window("Timeline", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        guard
            let index = args.firstIndex(of: "--render-snapshots"),
            index + 1 < args.count
        else { return }
        let dir = URL(fileURLWithPath: args[index + 1])
        Task { @MainActor in
            do {
                try await SnapshotRenderer.renderAll(to: dir)
            } catch {
                let message = "snapshot render failed: \(error)\n"
                FileHandle.standardError.write(message.data(using: .utf8)!)
            }
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
