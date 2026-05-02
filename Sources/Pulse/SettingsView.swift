import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var monitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var loginAtLogin: Bool = LoginItem.isEnabled
    @State private var primaryHostText: String = ""
    @State private var secondaryHostText: String = ""

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        hostsSection
                        frequencySection
                        powerSection
                        notificationsSection
                        diagnosticsSection
                        menuBarSection
                        systemSection
                        dangerSection
                    }
                    .padding(20)
                }
                footer
            }
        }
        .frame(width: 520, height: 700)
        .preferredColorScheme(.dark)
        .onAppear {
            primaryHostText = monitor.settings.primaryHost
            secondaryHostText = monitor.settings.secondaryHost
        }
        .onDisappear { commitHosts() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.brandGradient)
                    .frame(width: 22, height: 22)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Pulse Settings")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle().fill(Theme.hairline).frame(height: 1),
            alignment: .bottom
        )
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { commitHosts(); dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
    }

    private var hostsSection: some View {
        section(title: "Hosts", subtitle: "Pulse pings two hosts in parallel to distinguish your link from a single server.") {
            HStack {
                Image(systemName: "1.circle.fill").foregroundStyle(Theme.accent)
                TextField("Primary host", text: $primaryHostText, prompt: Text("1.1.1.1"))
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Image(systemName: "2.circle.fill").foregroundStyle(Theme.accent2)
                TextField("Secondary host", text: $secondaryHostText, prompt: Text("8.8.8.8"))
                    .textFieldStyle(.roundedBorder)
            }
            Stepper(value: Binding(
                get: { monitor.settings.pingsPerSample },
                set: { monitor.settings.pingsPerSample = max(1, min(10, $0)) }
            ), in: 1...10) {
                Text("Pings per sample: \(monitor.settings.pingsPerSample)").foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var frequencySection: some View {
        section(title: "Frequency") {
            Picker("Refresh", selection: Binding(
                get: { monitor.settings.pingInterval },
                set: { monitor.settings.pingInterval = $0 }
            )) {
                ForEach(PingInterval.allCases) { i in Text(i.label).tag(i) }
            }
            .pickerStyle(.segmented)

            Stepper(value: Binding(
                get: { monitor.settings.speedTestIntervalMinutes },
                set: { monitor.settings.speedTestIntervalMinutes = max(1, min(120, $0)) }
            ), in: 1...120) {
                Text("Speed test every \(monitor.settings.speedTestIntervalMinutes) min")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var powerSection: some View {
        section(title: "Power") {
            Toggle("Reduce frequency on battery", isOn: Binding(
                get: { monitor.settings.enableBatteryBackoff },
                set: { monitor.settings.enableBatteryBackoff = $0 }
            ))
            if monitor.settings.enableBatteryBackoff {
                Stepper(value: Binding(
                    get: { monitor.settings.batteryBackoffMultiplier },
                    set: { monitor.settings.batteryBackoffMultiplier = max(1.5, min(10, $0)) }
                ), in: 1.5...10, step: 0.5) {
                    Text(String(format: "Multiplier: %.1f×", monitor.settings.batteryBackoffMultiplier))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var notificationsSection: some View {
        section(title: "Notifications") {
            Toggle("Notify on outage / restored", isOn: Binding(
                get: { monitor.settings.enableNotifications },
                set: { monitor.settings.enableNotifications = $0 }
            ))
            Toggle("Alert on latency spike", isOn: Binding(
                get: { monitor.settings.enableLatencyAlert },
                set: { monitor.settings.enableLatencyAlert = $0 }
            ))
            .disabled(!monitor.settings.enableNotifications)
            if monitor.settings.enableLatencyAlert {
                Stepper(value: Binding(
                    get: { monitor.settings.latencyAlertThresholdMs },
                    set: { monitor.settings.latencyAlertThresholdMs = max(50, min(5000, $0)) }
                ), in: 50...5000, step: 25) {
                    Text("Threshold: \(Int(monitor.settings.latencyAlertThresholdMs)) ms")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        section(title: "Diagnostics") {
            Toggle("Auto-traceroute on outage", isOn: Binding(
                get: { monitor.settings.enableAutoTraceroute },
                set: { monitor.settings.enableAutoTraceroute = $0 }
            ))
        }
    }

    private var menuBarSection: some View {
        section(title: "Menu bar") {
            Toggle("Show ping number in menu bar", isOn: Binding(
                get: { monitor.settings.showPingInMenuBar },
                set: { monitor.settings.showPingInMenuBar = $0 }
            ))
        }
    }

    private var systemSection: some View {
        section(title: "System") {
            Toggle("Launch at login", isOn: $loginAtLogin)
                .onChange(of: loginAtLogin) { newValue in
                    _ = LoginItem.setEnabled(newValue)
                    loginAtLogin = LoginItem.isEnabled
                }
            HStack {
                Image(systemName: "folder").foregroundStyle(Theme.textTertiary)
                Text("Data folder").foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Persistence.folderURL])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Theme.accent)
            }
        }
    }

    private var dangerSection: some View {
        section(title: "Danger zone") {
            Button(role: .destructive) {
                monitor.clearHistory()
            } label: {
                Label("Clear all history", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(Theme.statusOffline)
        }
    }

    @ViewBuilder
    private func section<C: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(Theme.textTertiary)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .pulseCard()
    }

    private func commitHosts() {
        let p = primaryHostText.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = secondaryHostText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty, p != monitor.settings.primaryHost {
            monitor.settings.primaryHost = p
        }
        if !s.isEmpty, s != monitor.settings.secondaryHost {
            monitor.settings.secondaryHost = s
        }
    }
}
