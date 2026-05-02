import Foundation
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    // Settings (persisted)
    @Published var settings: AppSettings {
        didSet {
            if oldValue.pingInterval != settings.pingInterval || oldValue.enableBatteryBackoff != settings.enableBatteryBackoff {
                schedulePingTimer()
            }
            if oldValue.speedTestIntervalMinutes != settings.speedTestIntervalMinutes {
                scheduleSpeedTimer()
            }
            Persistence.saveSettings(settings)
        }
    }

    // Per-host history
    @Published private(set) var primaryHistory: [PingSample] = []
    @Published private(set) var secondaryHistory: [PingSample] = []
    @Published private(set) var speedHistory: [SpeedSample] = []
    @Published private(set) var outages: [OutageEvent] = []
    @Published private(set) var networkInfo: NetworkInfo = NetworkInfo()
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var currentPing: Double? = nil
    @Published private(set) var currentJitter: Double? = nil
    @Published private(set) var currentLoss: Double? = nil
    @Published private(set) var lastSpeed: SpeedSample? = nil
    @Published private(set) var isRunningSpeedTest: Bool = false
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var powerSource: PowerSource = .unknown
    @Published private(set) var lastTraceroute: String? = nil

    private var pingTimer: Timer?
    private var speedTimer: Timer?
    private var infoTimer: Timer?
    private let maxHistoryInMemory = 2_000
    private var lastLatencyAlertAt: Date? = nil
    private let latencyAlertCooldown: TimeInterval = 300

    init() {
        self.settings = Persistence.loadSettings()
        self.primaryHistory = Persistence.loadPings().filter { $0.host == settings.primaryHost }
        self.secondaryHistory = Persistence.loadPings().filter { $0.host == settings.secondaryHost }
        self.speedHistory = Persistence.loadSpeeds()
        self.outages = Persistence.loadOutages()
        self.lastSpeed = speedHistory.last
        if let lastPrimary = primaryHistory.last {
            self.isOnline = lastPrimary.isOnline
            self.currentPing = lastPrimary.latencyMs
            self.currentJitter = lastPrimary.jitterMs
            self.currentLoss = lastPrimary.lossPct
            self.lastUpdated = lastPrimary.timestamp
        }
    }

    // MARK: - Lifecycle

    func start() {
        Task { await refreshNetworkInfo() }
        Task { await pingCycle() }
        Task { await speedTest() }
        schedulePingTimer()
        scheduleSpeedTimer()
        scheduleInfoTimer()
    }

    func stop() {
        pingTimer?.invalidate()
        speedTimer?.invalidate()
        infoTimer?.invalidate()
    }

    // MARK: - Public actions

    func runPingNow() { Task { await pingCycle() } }
    func runSpeedTestNow() { Task { await speedTest() } }
    func refreshInfoNow() { Task { await refreshNetworkInfo() } }

    func runTracerouteNow() {
        Task {
            let host = settings.primaryHost
            if let s = await Traceroute.run(host: host) {
                self.lastTraceroute = s
            }
        }
    }

    func clearHistory() {
        primaryHistory.removeAll()
        secondaryHistory.removeAll()
        speedHistory.removeAll()
        outages.removeAll()
        Persistence.savePings([])
        Persistence.saveSpeeds([])
        Persistence.saveOutages([])
        currentPing = nil
        currentJitter = nil
        currentLoss = nil
        lastSpeed = nil
    }

    /// CSV export of all ping samples + outages, suitable for ISP complaints.
    func exportCSV() -> String {
        var rows: [String] = []
        rows.append("timestamp,host,attempts,received,loss_pct,latency_ms,jitter_ms,min_ms,max_ms")
        let fmt = ISO8601DateFormatter()
        let allPings = (primaryHistory + secondaryHistory).sorted { $0.timestamp < $1.timestamp }
        for s in allPings {
            rows.append([
                fmt.string(from: s.timestamp),
                s.host,
                "\(s.attempts)",
                "\(s.received)",
                String(format: "%.1f", s.lossPct),
                s.latencyMs.map { String(format: "%.2f", $0) } ?? "",
                s.jitterMs.map { String(format: "%.2f", $0) } ?? "",
                s.minMs.map { String(format: "%.2f", $0) } ?? "",
                s.maxMs.map { String(format: "%.2f", $0) } ?? ""
            ].joined(separator: ","))
        }
        rows.append("")
        rows.append("# outages")
        rows.append("start,end,duration_seconds,network")
        for o in outages.sorted(by: { $0.start < $1.start }) {
            rows.append([
                fmt.string(from: o.start),
                o.end.map { fmt.string(from: $0) } ?? "ongoing",
                String(format: "%.0f", o.duration),
                o.networkFingerprint ?? ""
            ].joined(separator: ","))
        }
        rows.append("")
        rows.append("# speed tests")
        rows.append("timestamp,download_mbps,upload_mbps,dl_responsiveness_rpm,ul_responsiveness_rpm")
        for s in speedHistory.sorted(by: { $0.timestamp < $1.timestamp }) {
            rows.append([
                fmt.string(from: s.timestamp),
                String(format: "%.2f", s.downloadMbps),
                String(format: "%.2f", s.uploadMbps),
                s.dlResponsivenessRpm.map { String(format: "%.0f", $0) } ?? "",
                s.ulResponsivenessRpm.map { String(format: "%.0f", $0) } ?? "",
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Timers

    private var effectivePingInterval: TimeInterval {
        let base = TimeInterval(settings.pingInterval.rawValue)
        if settings.enableBatteryBackoff && powerSource == .battery {
            return base * settings.batteryBackoffMultiplier
        }
        return base
    }

    private func schedulePingTimer() {
        pingTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: effectivePingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.pingCycle() }
        }
        RunLoop.main.add(t, forMode: .common)
        pingTimer = t
    }

    private func scheduleSpeedTimer() {
        speedTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.speedTestIntervalMinutes * 60),
                                     repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.speedTest() }
        }
        RunLoop.main.add(t, forMode: .common)
        speedTimer = t
    }

    private func scheduleInfoTimer() {
        infoTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshNetworkInfo() }
        }
        RunLoop.main.add(t, forMode: .common)
        infoTimer = t
    }

    // MARK: - Ping cycle

    private func pingCycle() async {
        powerSource = PowerMonitor.current()

        async let primary = pingHost(settings.primaryHost, count: settings.pingsPerSample)
        async let secondary = pingHost(settings.secondaryHost, count: settings.pingsPerSample)
        let (p, s) = await (primary, secondary)

        primaryHistory.append(p)
        if primaryHistory.count > maxHistoryInMemory {
            primaryHistory.removeFirst(primaryHistory.count - maxHistoryInMemory)
        }
        secondaryHistory.append(s)
        if secondaryHistory.count > maxHistoryInMemory {
            secondaryHistory.removeFirst(secondaryHistory.count - maxHistoryInMemory)
        }

        currentPing = p.latencyMs
        currentJitter = p.jitterMs
        currentLoss = p.lossPct
        lastUpdated = Date()

        // Online if at least primary OR secondary received any reply
        let nowOnline = p.isOnline || s.isOnline
        if nowOnline != isOnline {
            if nowOnline {
                if let i = outages.indices.last, outages[i].end == nil {
                    outages[i].end = Date()
                    if settings.enableNotifications {
                        let dur = formatDuration(outages[i].duration)
                        NotificationsManager.shared.notify(
                            title: "Internet restored",
                            body: "Outage lasted \(dur)."
                        )
                    }
                }
            } else {
                let outage = OutageEvent(
                    start: Date(),
                    end: nil,
                    traceroute: nil,
                    networkFingerprint: networkInfo.fingerprint
                )
                outages.append(outage)
                if settings.enableNotifications {
                    NotificationsManager.shared.notify(
                        title: "Internet down",
                        body: "Both \(settings.primaryHost) and \(settings.secondaryHost) unreachable."
                    )
                }
                if settings.enableAutoTraceroute {
                    Task { @MainActor in
                        if let trace = await Traceroute.run(host: self.settings.primaryHost) {
                            if let last = self.outages.indices.last {
                                self.outages[last].traceroute = trace
                                self.lastTraceroute = trace
                                Persistence.saveOutages(self.outages)
                            }
                        }
                    }
                }
            }
            isOnline = nowOnline
        }

        // Latency spike alert
        if settings.enableNotifications, settings.enableLatencyAlert,
           let v = p.latencyMs, v > settings.latencyAlertThresholdMs {
            let now = Date()
            if let last = lastLatencyAlertAt, now.timeIntervalSince(last) < latencyAlertCooldown {
                // cooldown
            } else {
                lastLatencyAlertAt = now
                NotificationsManager.shared.notify(
                    title: "Latency spike",
                    body: "Ping to \(settings.primaryHost) is \(Int(v.rounded())) ms (threshold \(Int(settings.latencyAlertThresholdMs)) ms)."
                )
            }
        }

        // Persist
        Persistence.savePings(primaryHistory + secondaryHistory)
        Persistence.saveOutages(outages)
    }

    private func pingHost(_ host: String, count: Int) async -> PingSample {
        let times = await Self.runPing(host: host, count: count)
        let received = times.count
        let attempts = max(count, 1)
        let mean = times.isEmpty ? nil : times.reduce(0, +) / Double(received)
        let minV = times.min()
        let maxV = times.max()
        let jitter: Double? = {
            guard times.count > 1, let m = mean else { return nil }
            let variance = times.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(times.count)
            return variance.squareRoot()
        }()
        return PingSample(
            timestamp: Date(),
            host: host,
            attempts: attempts,
            received: received,
            latencyMs: mean,
            jitterMs: jitter,
            minMs: minV,
            maxMs: maxV
        )
    }

    private static func runPing(host: String, count: Int) async -> [Double] {
        await Task.detached(priority: .background) { () -> [Double] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // -i 0.2 needs root on some systems; fall back to default 1s if needed
            process.arguments = ["-c", "\(count)", "-t", "\(max(2, count))", host]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard let s = String(data: data, encoding: .utf8) else { return [] }
                let regex = try? NSRegularExpression(pattern: #"time=([0-9]+(?:\.[0-9]+)?)"#)
                let range = NSRange(s.startIndex..., in: s)
                let matches = regex?.matches(in: s, range: range) ?? []
                return matches.compactMap { m -> Double? in
                    guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: s) else { return nil }
                    return Double(s[r])
                }
            } catch {
                return []
            }
        }.value
    }

    // MARK: - Speed test

    private func speedTest() async {
        guard !isRunningSpeedTest else { return }
        isRunningSpeedTest = true
        defer { isRunningSpeedTest = false }
        if let s = await Self.runNetworkQuality() {
            speedHistory.append(s)
            if speedHistory.count > 1000 {
                speedHistory.removeFirst(speedHistory.count - 1000)
            }
            lastSpeed = s
            Persistence.saveSpeeds(speedHistory)
        }
    }

    private static func runNetworkQuality() async -> SpeedSample? {
        await Task.detached(priority: .background) { () -> SpeedSample? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
            process.arguments = ["-s", "-c"]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                func dbl(_ key: String) -> Double? {
                    if let v = json[key] as? Double { return v }
                    if let v = (json[key] as? NSNumber)?.doubleValue { return v }
                    return nil
                }
                let dlBps = dbl("dl_throughput") ?? 0
                let ulBps = dbl("ul_throughput") ?? 0
                let dlRpm = dbl("dl_responsiveness")
                let ulRpm = dbl("ul_responsiveness")
                guard dlBps > 0 || ulBps > 0 else { return nil }
                return SpeedSample(
                    timestamp: Date(),
                    downloadMbps: dlBps / 1_000_000,
                    uploadMbps: ulBps / 1_000_000,
                    dlResponsivenessRpm: dlRpm,
                    ulResponsivenessRpm: ulRpm
                )
            } catch {
                return nil
            }
        }.value
    }

    // MARK: - Network info

    private func refreshNetworkInfo() async {
        let info = await NetworkInfoProvider.gather()
        self.networkInfo = info
        self.powerSource = PowerMonitor.current()
        if info.isCaptivePortal && settings.enableNotifications {
            NotificationsManager.shared.notify(
                title: "Captive portal detected",
                body: "Open your browser to sign in to this Wi-Fi network."
            )
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let total = Int(s.rounded())
        if total < 60 { return "\(total)s" }
        let m = total / 60, sec = total % 60
        if m < 60 { return "\(m)m \(sec)s" }
        let h = m / 60, mm = m % 60
        return "\(h)h \(mm)m"
    }
}
