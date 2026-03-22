import Darwin
import Foundation

enum DNSManager {
    /// Sets DNS servers for the given network service.
    /// Pass an empty array to revert to automatic (DHCP) DNS.
    static func setDNS(servers: [String], serviceName: String) throws {
        let args: [String]
        if servers.isEmpty {
            args = ["-setdnsservers", serviceName, "Empty"]
        } else {
            args = ["-setdnsservers", serviceName] + servers
        }
        print("[DNSManager] networksetup args: \(args)")

        try sendToHelper(args: args)
    }

    private static func sendToHelper(args: [String]) throws {
        let socketPath = "/var/run/simpledns.sock"

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw AppError.dnsChangeFailed("Helper daemon not running — re-run install.sh")
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: 104) {
                    _ = strlcpy($0, ptr, 104)
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            throw AppError.dnsChangeFailed("Helper daemon not running — re-run install.sh")
        }

        let payload = try JSONSerialization.data(withJSONObject: ["args": args])
        var payloadWithNewline = payload
        payloadWithNewline.append(UInt8(ascii: "\n"))
        try payloadWithNewline.withUnsafeBytes { ptr in
            guard send(fd, ptr.baseAddress!, payloadWithNewline.count, 0) == payloadWithNewline.count else {
                throw AppError.dnsChangeFailed("Failed to send request to helper")
            }
        }

        var responseData = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = recv(fd, &buf, buf.count, 0)
            if n <= 0 { break }
            responseData.append(contentsOf: buf[0..<n])
            if n < buf.count { break }
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let ok = json["ok"] as? Bool
        else {
            throw AppError.dnsChangeFailed("Invalid response from helper")
        }

        if !ok {
            let msg = json["error"] as? String ?? "Unknown error"
            throw AppError.dnsChangeFailed("networksetup failed: \(msg)")
        }
    }
}
