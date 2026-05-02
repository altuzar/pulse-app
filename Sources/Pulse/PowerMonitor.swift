import Foundation
import IOKit.ps

enum PowerSource {
    case ac, battery, unknown
}

enum PowerMonitor {
    /// Returns whether the Mac is currently on battery (as opposed to AC power).
    static func current() -> PowerSource {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return .unknown }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unknown
        }
        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                if state == kIOPSACPowerValue { return .ac }
                if state == kIOPSBatteryPowerValue { return .battery }
            }
        }
        return .unknown
    }
}
