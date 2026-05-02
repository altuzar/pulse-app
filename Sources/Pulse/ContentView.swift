import SwiftUI
import Charts
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var monitor: NetworkMonitor
    @State private var showSettings = false
    @State private var showTraceroute = false
    @State private var showExporter = false
    @State private var exportDoc: CSVDocument? = nil

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            // Ambient color blobs
            GeometryReader { geo in
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 120)
                    .position(x: geo.size.width * 0.05, y: -40)
                Circle()
                    .fill(Theme.accent2.opacity(0.14))
                    .frame(width: geo.size.width * 0.55)
                    .blur(radius: 130)
                    .position(x: geo.size.width * 0.95, y: geo.size.height * 0.95)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    brandHeader
                    statusHero
                    statRow
                    networkInfoCard
                    pingChartCard
                    speedChartCard
                    outagesCard
                    bottomBar
                }
                .padding(22)
            }
        }
        .frame(minWidth: 880, minHeight: 760)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(monitor)
        }
        .sheet(isPresented: $showTraceroute) {
            TracerouteView(text: monitor.lastTraceroute, host: monitor.settings.primaryHost) {
                monitor.runTracerouteNow()
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDoc,
            contentType: .commaSeparatedText,
            defaultFilename: defaultExportName()
        ) { _ in }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ToolbarButton(icon: "bolt.fill", label: "Ping now") { monitor.runPingNow() }
                ToolbarButton(icon: monitor.isRunningSpeedTest ? "hourglass" : "speedometer",
                              label: monitor.isRunningSpeedTest ? "Testing…" : "Speed test",
                              disabled: monitor.isRunningSpeedTest) {
                    monitor.runSpeedTestNow()
                }
                ToolbarButton(icon: "point.3.connected.trianglepath.dotted", label: "Traceroute") {
                    showTraceroute = true
                }
                ToolbarButton(icon: "square.and.arrow.up", label: "Export") {
                    exportDoc = CSVDocument(text: monitor.exportCSV())
                    showExporter = true
                }
                ToolbarButton(icon: "gearshape.fill", label: "Settings") {
                    showSettings = true
                }
            }
        }
    }

    // MARK: - Brand header

    private var brandHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.brandGradient)
                    .frame(width: 32, height: 32)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Pulse")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your internet, in real time")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if monitor.powerSource == .battery, monitor.settings.enableBatteryBackoff {
                BadgeChip(icon: "battery.50", text: "Battery", tint: Theme.statusWarn)
            }
            if monitor.networkInfo.isCaptivePortal {
                BadgeChip(icon: "exclamationmark.triangle.fill", text: "Captive portal", tint: Theme.statusWarn)
            }
        }
    }

    // MARK: - Status hero

    private var statusHero: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 14) {
                PulseDot(color: monitor.isOnline ? Theme.statusOnline : Theme.statusOffline, size: 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.isOnline ? "Online" : "Offline")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(monitor.isOnline ? Theme.textPrimary : Theme.statusOffline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            HStack(spacing: 22) {
                MetricChip(label: "Ping",
                           value: monitor.currentPing.map { "\(Int($0.rounded())) ms" } ?? "—",
                           tint: pingTint(monitor.currentPing))
                Divider().frame(height: 36).overlay(Theme.hairline)
                MetricChip(label: "Jitter",
                           value: monitor.currentJitter.map { String(format: "%.1f ms", $0) } ?? "—",
                           tint: Theme.textPrimary)
                Divider().frame(height: 36).overlay(Theme.hairline)
                MetricChip(label: "Loss",
                           value: monitor.currentLoss.map { String(format: "%.0f%%", $0) } ?? "—",
                           tint: (monitor.currentLoss ?? 0) > 0 ? Theme.statusOffline : Theme.textPrimary)
                Divider().frame(height: 36).overlay(Theme.hairline)
                MetricChip(label: "Down",
                           value: monitor.lastSpeed.map { fmtMbps($0.downloadMbps) } ?? "—",
                           tint: Theme.accent)
                Divider().frame(height: 36).overlay(Theme.hairline)
                MetricChip(label: "Up",
                           value: monitor.lastSpeed.map { fmtMbps($0.uploadMbps) } ?? "—",
                           tint: Theme.accent2)
            }
        }
        .pulseCard(padding: 22)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let t = monitor.lastUpdated {
            let fmt = DateFormatter(); fmt.timeStyle = .medium
            parts.append("Last check \(fmt.string(from: t))")
        }
        parts.append("primary \(monitor.settings.primaryHost)")
        return parts.joined(separator: " · ")
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 12) {
            statTile("Uptime today", uptimePctToday(), Theme.statusOnline)
            statTile("Outages today", "\(outagesToday())", outagesToday() > 0 ? Theme.statusOffline : Theme.textPrimary)
            statTile("Avg ping (1h)", avgPing1h(), Theme.accent)
            statTile("Worst ping (1h)", worstPing1h(), Theme.statusWarn)
            statTile("Samples", "\(monitor.primaryHistory.count)", Theme.textPrimary)
        }
    }

    private func statTile(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseCard(padding: 14)
    }

    // MARK: - Network info

    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Network",
                         trailing: monitor.networkInfo.fingerprint.isEmpty ? nil : monitor.networkInfo.fingerprint)
            HStack(spacing: 22) {
                infoBlock(icon: "globe", label: "Public IP", value: monitor.networkInfo.publicIP ?? "—")
                infoBlock(icon: "house", label: "Local IP", value: monitor.networkInfo.localIP ?? "—")
                infoBlock(icon: "arrow.triangle.branch", label: "Gateway", value: monitor.networkInfo.gatewayIP ?? "—")
                infoBlock(icon: "antenna.radiowaves.left.and.right", label: "Interface", value: monitor.networkInfo.interfaceName ?? "—")
                Spacer()
                Button {
                    monitor.refreshInfoNow()
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Theme.accent)
            }
        }
        .pulseCard()
    }

    private func infoBlock(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label.uppercased(), systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    // MARK: - Charts

    private var pingChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(title: "Latency")
                Spacer()
                HStack(spacing: 14) {
                    legendDot(Theme.accent, monitor.settings.primaryHost)
                    legendDot(Theme.accent2.opacity(0.85), monitor.settings.secondaryHost)
                }
            }
            if monitor.primaryHistory.isEmpty {
                placeholder("Collecting samples…")
            } else {
                Chart {
                    if monitor.settings.enableLatencyAlert {
                        RuleMark(y: .value("Threshold", monitor.settings.latencyAlertThresholdMs))
                            .foregroundStyle(Theme.statusWarn.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .topTrailing, alignment: .trailing) {
                                Text("Alert \(Int(monitor.settings.latencyAlertThresholdMs)) ms")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.statusWarn)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.statusWarn.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                    }
                    ForEach(monitor.primaryHistory) { s in
                        if let v = s.latencyMs {
                            AreaMark(
                                x: .value("Time", s.timestamp),
                                y: .value("ms", v),
                                series: .value("series", "primary")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.30), Theme.accent.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Time", s.timestamp),
                                y: .value("ms", v),
                                series: .value("series", "primary")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        }
                    }
                    ForEach(monitor.secondaryHistory) { s in
                        if let v = s.latencyMs {
                            LineMark(
                                x: .value("Time", s.timestamp),
                                y: .value("ms", v),
                                series: .value("series", "secondary")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accent2.opacity(0.85))
                            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 3]))
                        }
                    }
                    ForEach(monitor.primaryHistory.filter { !$0.isOnline }) { s in
                        PointMark(
                            x: .value("Time", s.timestamp),
                            y: .value("ms", 0)
                        )
                        .foregroundStyle(Theme.statusOffline)
                        .symbolSize(80)
                        .symbol(.circle)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisTick().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisTick().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .pulseCard()
    }

    private var speedChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(title: "Throughput")
                Spacer()
                HStack(spacing: 14) {
                    legendDot(Theme.accent, "Down")
                    legendDot(Theme.accent2, "Up")
                }
            }
            if monitor.speedHistory.isEmpty {
                placeholder(monitor.isRunningSpeedTest ? "Running speed test…" : "No speed samples yet — first run starts shortly")
            } else {
                Chart {
                    ForEach(monitor.speedHistory) { s in
                        AreaMark(
                            x: .value("Time", s.timestamp),
                            y: .value("Mbps", s.downloadMbps),
                            series: .value("Series", "Down")
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.32), Theme.accent.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom)
                        )
                        LineMark(
                            x: .value("Time", s.timestamp),
                            y: .value("Mbps", s.downloadMbps),
                            series: .value("Series", "Down")
                        )
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        AreaMark(
                            x: .value("Time", s.timestamp),
                            y: .value("Mbps", s.uploadMbps),
                            series: .value("Series", "Up")
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accent2.opacity(0.28), Theme.accent2.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom)
                        )
                        LineMark(
                            x: .value("Time", s.timestamp),
                            y: .value("Mbps", s.uploadMbps),
                            series: .value("Series", "Up")
                        )
                        .foregroundStyle(Theme.accent2)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisTick().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisTick().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .pulseCard()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Outages

    private var outagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Recent outages",
                         trailing: monitor.outages.isEmpty ? nil : "\(monitor.outages.count) total")
            if monitor.outages.isEmpty {
                placeholder("None — connection has been stable")
            } else {
                VStack(spacing: 8) {
                    ForEach(monitor.outages.suffix(8).reversed()) { o in
                        outageRow(o)
                    }
                }
            }
        }
        .pulseCard()
    }

    private func outageRow(_ o: OutageEvent) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill((o.isOngoing ? Theme.statusOffline : Theme.textTertiary).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: o.isOngoing ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(o.isOngoing ? Theme.statusOffline : Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(o.start, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                        .font(.system(.callout, design: .monospaced).weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("→").foregroundStyle(Theme.textTertiary)
                    Group {
                        if let end = o.end {
                            Text(end, style: .time)
                        } else {
                            Text("ongoing").foregroundStyle(Theme.statusOffline)
                        }
                    }
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                }
                if o.traceroute != nil {
                    Label("Traceroute captured", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Text(formatDuration(o.duration))
                .font(.system(.callout, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(o.isOngoing ? Theme.statusOffline : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((o.isOngoing ? Theme.statusOffline : Theme.textSecondary).opacity(0.10))
                )
        }
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(Persistence.folderURL.path)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("\(monitor.outages.count) outages · \(monitor.primaryHistory.count + monitor.secondaryHistory.count) ping samples · \(monitor.speedHistory.count) speed samples")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func pingTint(_ v: Double?) -> Color {
        guard let v else { return Theme.statusOffline }
        if v < 40 { return Theme.statusOnline }
        if v < 100 { return Theme.statusWarn }
        return Theme.accent2
    }

    private func fmtMbps(_ v: Double) -> String {
        if v >= 100 { return String(format: "%.0f Mbps", v) }
        return String(format: "%.1f Mbps", v)
    }

    private func uptimePctToday() -> String {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let samples = monitor.primaryHistory.filter { $0.timestamp >= startOfDay }
        guard !samples.isEmpty else { return "—" }
        let online = samples.filter { $0.isOnline }.count
        let pct = Double(online) / Double(samples.count) * 100
        return String(format: "%.1f%%", pct)
    }

    private func outagesToday() -> Int {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        return monitor.outages.filter { $0.start >= startOfDay }.count
    }

    private func avgPing1h() -> String {
        let cutoff = Date().addingTimeInterval(-3600)
        let recent = monitor.primaryHistory.filter { $0.timestamp >= cutoff }.compactMap { $0.latencyMs }
        guard !recent.isEmpty else { return "—" }
        let avg = recent.reduce(0, +) / Double(recent.count)
        return "\(Int(avg.rounded())) ms"
    }

    private func worstPing1h() -> String {
        let cutoff = Date().addingTimeInterval(-3600)
        let recent = monitor.primaryHistory.filter { $0.timestamp >= cutoff }.compactMap { $0.latencyMs }
        guard let m = recent.max() else { return "—" }
        return "\(Int(m.rounded())) ms"
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let total = Int(s.rounded())
        if total < 60 { return "\(total)s" }
        let m = total / 60, sec = total % 60
        if m < 60 { return "\(m)m \(sec)s" }
        let h = m / 60, mm = m % 60
        return "\(h)h \(mm)m"
    }

    private func defaultExportName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return "pulse-\(f.string(from: Date())).csv"
    }
}

// MARK: - Toolbar button

struct ToolbarButton: View {
    let icon: String
    let label: String
    var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
        }
        .disabled(disabled)
        .help(label)
    }
}

// MARK: - Badge chip

struct BadgeChip: View {
    let icon: String
    let text: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 0.8))
    }
}

// MARK: - CSV doc

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let s = String(data: data, encoding: .utf8) {
            self.text = s
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}
