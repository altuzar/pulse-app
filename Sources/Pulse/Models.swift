import Foundation

struct PingSample: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let timestamp: Date
    let host: String
    let attempts: Int
    let received: Int
    let latencyMs: Double?     // mean of received pings
    let jitterMs: Double?      // stddev of received times
    let minMs: Double?
    let maxMs: Double?

    var lossPct: Double {
        attempts == 0 ? 0 : Double(attempts - received) / Double(attempts) * 100.0
    }
    var isOnline: Bool { received > 0 }
}

struct SpeedSample: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let timestamp: Date
    let downloadMbps: Double
    let uploadMbps: Double
    let dlResponsivenessRpm: Double?
    let ulResponsivenessRpm: Double?
}

struct OutageEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let start: Date
    var end: Date?
    var traceroute: String?    // captured at outage onset
    var networkFingerprint: String?

    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
    var isOngoing: Bool { end == nil }
}

struct NetworkInfo: Codable, Equatable {
    var publicIP: String?
    var localIP: String?
    var gatewayIP: String?
    var interfaceName: String?
    var isCaptivePortal: Bool = false
    var captivePortalCheckedAt: Date?

    var fingerprint: String {
        [interfaceName, gatewayIP, localIP].compactMap { $0 }.joined(separator: "|")
    }
}

enum PingInterval: Int, CaseIterable, Identifiable, Codable {
    case s30 = 30, m1 = 60, m2 = 120, m5 = 300
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .s30: return "30 sec"
        case .m1:  return "1 min"
        case .m2:  return "2 min"
        case .m5:  return "5 min"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var pingInterval: PingInterval = .m1
    var primaryHost: String = "1.1.1.1"
    var secondaryHost: String = "8.8.8.8"
    var pingsPerSample: Int = 3
    var speedTestIntervalMinutes: Int = 10
    var enableNotifications: Bool = true
    var latencyAlertThresholdMs: Double = 250
    var enableLatencyAlert: Bool = false
    var enableBatteryBackoff: Bool = true
    var batteryBackoffMultiplier: Double = 3.0
    var enableAutoTraceroute: Bool = true
    var showPingInMenuBar: Bool = true
    var pinPrimaryHostInChart: Bool = true

    static let defaults = AppSettings()
}

enum HostRole: String, Codable {
    case primary, secondary
}
