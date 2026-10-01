import SwiftUI
import ServiceManagement

@main
struct X7ControlApp: App {
    init() {
        migrateProvisionalPreferencesIfNeeded()
    }

    var body: some Scene {
        Window("MB X7 Control", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MB X7 Control") {
                    showMBX7AboutPanel()
                }
            }
        }

        MenuBarExtra("MB X7 Control", systemImage: "waveform.circle.fill") {
            MenuBarContent()
        }
    }
}

private func migrateProvisionalPreferencesIfNeeded() {
    let provisionalIdentifier = "io.github.x7control.X7Control"
    let permanentIdentifier = "io.github.alcatron.MBX7Control"
    let marker = "migration.\(provisionalIdentifier).completed"
    let defaults = UserDefaults.standard

    guard Bundle.main.bundleIdentifier == permanentIdentifier,
          !defaults.bool(forKey: marker) else { return }

    if let provisional = defaults.persistentDomain(forName: provisionalIdentifier) {
        for (key, value) in provisional where key.hasPrefix("device.") || key.hasPrefix("audio.") {
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
    }

    defaults.set(true, forKey: marker)
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Button("Show MB X7 Control") {
            showMainWindow()
        }

        Divider()

        Button("About MB X7 Control") {
            showMBX7AboutPanel()
        }

        Divider()

        Toggle("Open at Login", isOn: Binding(
            get: { opensAtLogin },
            set: updateOpenAtLogin
        ))

        if let loginItemError {
            Text(loginItemError)
        }

        Divider()

        Button("Quit MB X7 Control") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear {
            opensAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func showMainWindow() {
        let app = NSApplication.shared
        if let window = app.windows.first(where: { $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        app.activate(ignoringOtherApps: true)
    }

    private func updateOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            opensAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = nil
        } catch {
            opensAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = "Could not update Open at Login."
        }
    }
}

func showMBX7AboutPanel() {
    let description = """
    Native Apple silicon controller for the Creative Sound Blaster X7.

    Independent interoperability project; not affiliated with or endorsed by Creative Technology Ltd.

    Source-available under MIT + Commons Clause v1.0. Sale and paid redistribution are not permitted.
    """
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    NSApplication.shared.orderFrontStandardAboutPanel(options: [
        .applicationName: "MB X7 Control",
        .applicationVersion: "\(version) (\(build))",
        .credits: NSAttributedString(string: description)
    ])
}
