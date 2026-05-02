import Foundation

enum Traceroute {
    /// Runs a quick traceroute and returns the raw textual output (or nil on failure).
    static func run(host: String, maxHops: Int = 20, perHopTimeoutSec: Int = 2, queriesPerHop: Int = 1) async -> String? {
        await Task.detached(priority: .background) { () -> String? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
            process.arguments = [
                "-n",                              // numeric only, faster
                "-m", "\(maxHops)",
                "-w", "\(perHopTimeoutSec)",
                "-q", "\(queriesPerHop)",
                host
            ]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard let s = String(data: data, encoding: .utf8) else { return nil }
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        }.value
    }
}
