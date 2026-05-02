import Foundation
import Darwin
import SystemConfiguration

enum NetworkInfoProvider {
    /// Best-effort gather of public/local IP, gateway, interface, captive-portal state.
    static func gather(currentPublicIP: String? = nil) async -> NetworkInfo {
        async let pub: String? = (currentPublicIP == nil) ? fetchPublicIP() : currentPublicIP
        async let captive = checkCaptivePortal()
        let local = primaryLocalIP()
        let gw = defaultGateway()
        let iface = primaryInterfaceName()

        return NetworkInfo(
            publicIP: await pub,
            localIP: local,
            gatewayIP: gw,
            interfaceName: iface,
            isCaptivePortal: await captive,
            captivePortalCheckedAt: Date()
        )
    }

    static func fetchPublicIP() async -> String? {
        await Task.detached(priority: .background) { () -> String? in
            guard let url = URL(string: "https://api.ipify.org") else { return nil }
            var req = URLRequest(url: url)
            req.timeoutInterval = 4
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
                let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let s, !s.isEmpty, s.count <= 45 else { return nil }
                return s
            } catch {
                return nil
            }
        }.value
    }

    /// Apple-style captive portal check: should return body "Success" with 200.
    static func checkCaptivePortal() async -> Bool {
        await Task.detached(priority: .background) { () -> Bool in
            guard let url = URL(string: "http://captive.apple.com/hotspot-detect.html") else { return false }
            var req = URLRequest(url: url)
            req.timeoutInterval = 3
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return false }
                let body = String(data: data, encoding: .utf8) ?? ""
                if http.statusCode == 200, body.contains("<TITLE>Success</TITLE>") || body.contains("Success") {
                    return false
                }
                // Anything else (redirect to login page, 302, body mismatch) = captive portal
                return true
            } catch {
                return false  // can't tell
            }
        }.value
    }

    static func primaryLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        var candidates: [(String, String, Bool)] = []  // ifname, ip, isIPv4

        while let p = ptr {
            let f = p.pointee
            ptr = f.ifa_next

            let flags = Int32(f.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = f.ifa_addr else { continue }
            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            let name = String(cString: f.ifa_name)
            // Skip non-interesting interfaces
            if name.hasPrefix("awdl") || name.hasPrefix("llw") || name.hasPrefix("utun") || name == "lo0" {
                continue
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let saLen = socklen_t(family == UInt8(AF_INET) ? MemoryLayout<sockaddr_in>.size : MemoryLayout<sockaddr_in6>.size)
            let result = getnameinfo(addr, saLen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else { continue }
            let ip = String(cString: hostBuffer)
            if ip.hasPrefix("fe80") { continue }  // link-local v6
            candidates.append((name, ip, family == UInt8(AF_INET)))
        }

        // Prefer en0/en1 IPv4
        if let en4 = candidates.first(where: { $0.0.hasPrefix("en") && $0.2 }) { return en4.1 }
        if let any4 = candidates.first(where: { $0.2 }) { return any4.1 }
        return candidates.first?.1
    }

    static func primaryInterfaceName() -> String? {
        // Run `route get default` to find primary interface
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let s = String(data: data, encoding: .utf8) else { return nil }
            for line in s.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("interface:") {
                    return t.replacingOccurrences(of: "interface:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}
        return nil
    }

    static func defaultGateway() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let s = String(data: data, encoding: .utf8) else { return nil }
            for line in s.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("gateway:") {
                    return t.replacingOccurrences(of: "gateway:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}
        return nil
    }
}
