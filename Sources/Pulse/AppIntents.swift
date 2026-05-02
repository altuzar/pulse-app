import Foundation
import AppIntents

@available(macOS 13.0, *)
struct GetLatestPingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Latest Ping"
    static var description = IntentDescription("Returns the most recent ping latency in milliseconds.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let monitor = SharedMonitor.instance
        let v = monitor.currentPing ?? -1
        if v < 0 {
            return .result(value: -1, dialog: IntentDialog("No ping sample yet — open SpeedTester first."))
        }
        return .result(value: v, dialog: IntentDialog("Latest ping is \(Int(v.rounded())) milliseconds."))
    }
}

@available(macOS 13.0, *)
struct CheckOnlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Check If Online"
    static var description = IntentDescription("Returns true if the network is currently online.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let monitor = SharedMonitor.instance
        return .result(value: monitor.isOnline,
                       dialog: IntentDialog(monitor.isOnline ? "Online." : "Offline."))
    }
}

@available(macOS 13.0, *)
struct RunSpeedTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Speed Test"
    static var description = IntentDescription("Runs a fresh speed test and returns download/upload Mbps.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let monitor = SharedMonitor.instance
        monitor.runSpeedTestNow()
        for _ in 0..<60 {
            if monitor.isRunningSpeedTest == false, let last = monitor.lastSpeed,
               last.timestamp.timeIntervalSinceNow > -90 {
                return .result(dialog: IntentDialog("Down \(Int(last.downloadMbps.rounded())) Mbps, up \(Int(last.uploadMbps.rounded())) Mbps."))
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return .result(dialog: IntentDialog("Speed test still running — check the app."))
    }
}

@available(macOS 13.0, *)
struct SpeedTesterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetLatestPingIntent(),
            phrases: ["Get latest ping from \(.applicationName)", "What's my ping in \(.applicationName)"],
            shortTitle: "Latest ping",
            systemImageName: "wifi"
        )
        AppShortcut(
            intent: CheckOnlineIntent(),
            phrases: ["Check if online with \(.applicationName)", "Am I online \(.applicationName)"],
            shortTitle: "Online?",
            systemImageName: "network"
        )
        AppShortcut(
            intent: RunSpeedTestIntent(),
            phrases: ["Run speed test in \(.applicationName)", "Speed test \(.applicationName)"],
            shortTitle: "Speed test",
            systemImageName: "speedometer"
        )
    }
}

/// A holder so App Intents (which run outside the SwiftUI scene graph) can find the
/// active monitor instance.
@MainActor
enum SharedMonitor {
    static let instance: NetworkMonitor = NetworkMonitor()
}
