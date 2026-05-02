import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var monitor: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(width: 22, height: 22)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pulse").font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        PulseDot(color: monitor.isOnline ? Theme.statusOnline : Theme.statusOffline, size: 6)
                        Text(monitor.isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(monitor.isOnline ? Theme.statusOnline : Theme.statusOffline)
                    }
                }
                Spacer()
                if monitor.networkInfo.isCaptivePortal {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.statusWarn)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().overlay(Theme.hairline)

            // Live metrics
            VStack(spacing: 6) {
                row(icon: "bolt.fill", label: "Ping",
                    value: monitor.currentPing.map { "\(Int($0.rounded())) ms" } ?? "—",
                    tint: pingTint(monitor.currentPing))
                row(icon: "waveform", label: "Jitter",
                    value: monitor.currentJitter.map { String(format: "%.1f ms", $0) } ?? "—",
                    tint: Theme.textPrimary)
                row(icon: "exclamationmark.octagon", label: "Loss",
                    value: monitor.currentLoss.map { String(format: "%.0f%%", $0) } ?? "—",
                    tint: (monitor.currentLoss ?? 0) > 0 ? Theme.statusOffline : Theme.textPrimary)
                row(icon: "arrow.down", label: "Down",
                    value: monitor.lastSpeed.map { String(format: "%.1f Mbps", $0.downloadMbps) } ?? "—",
                    tint: Theme.accent)
                row(icon: "arrow.up", label: "Up",
                    value: monitor.lastSpeed.map { String(format: "%.1f Mbps", $0.uploadMbps) } ?? "—",
                    tint: Theme.accent2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().overlay(Theme.hairline)

            // Network info
            VStack(spacing: 6) {
                if let ip = monitor.networkInfo.publicIP {
                    row(icon: "globe", label: "Public IP", value: ip, tint: Theme.textSecondary)
                }
                if let g = monitor.networkInfo.gatewayIP {
                    row(icon: "arrow.triangle.branch", label: "Gateway", value: g, tint: Theme.textSecondary)
                }
                if let t = monitor.lastUpdated {
                    row(icon: "clock", label: "Updated", value: relTime(t), tint: Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().overlay(Theme.hairline)

            // Actions
            VStack(spacing: 0) {
                actionButton(icon: "bolt.fill", title: "Ping now") { monitor.runPingNow() }
                actionButton(icon: monitor.isRunningSpeedTest ? "hourglass" : "speedometer",
                             title: monitor.isRunningSpeedTest ? "Speed test running…" : "Run speed test",
                             disabled: monitor.isRunningSpeedTest) {
                    monitor.runSpeedTestNow()
                }
                actionButton(icon: "point.3.connected.trianglepath.dotted", title: "Run traceroute") {
                    monitor.runTracerouteNow()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider().overlay(Theme.hairline)

            VStack(spacing: 0) {
                actionButton(icon: "macwindow", title: "Open Pulse window") {
                    NSApp.activate(ignoringOtherApps: true)
                    for w in NSApp.windows where w.canBecomeMain { w.makeKeyAndOrderFront(nil) }
                }
                actionButton(icon: "power", title: "Quit Pulse") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 270)
        .background(Theme.bgGradient)
    }

    private func row(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 16)
            Text(label).foregroundStyle(Theme.textSecondary)
                .font(.system(size: 12))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
        }
    }

    private func actionButton(icon: String, title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(disabled ? Theme.textTertiary : Theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func pingTint(_ v: Double?) -> Color {
        guard let v else { return Theme.statusOffline }
        if v < 40 { return Theme.statusOnline }
        if v < 100 { return Theme.statusWarn }
        return Theme.accent2
    }

    private func relTime(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "\(s)s ago" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        return "\(h)h ago"
    }
}
