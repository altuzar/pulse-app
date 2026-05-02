import SwiftUI
import AppKit

@main
struct PulseApp: App {
    @StateObject private var monitor = SharedMonitor.instance

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        Task { @MainActor in
            await NotificationsManager.shared.requestAuthorizationIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup("Pulse") {
            ContentView()
                .environmentObject(monitor)
                .preferredColorScheme(.dark)
                .onAppear { monitor.start() }
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
                .preferredColorScheme(.dark)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: monitor.isOnline ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
                if monitor.settings.showPingInMenuBar, let p = monitor.currentPing {
                    Text("\(Int(p.rounded()))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
