import Foundation

struct NetworkMapping: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var ssid: String
    var dnsServers: [String]  // empty = revert to automatic
}

enum AppError: LocalizedError {
    case dnsChangeFailed(String)
    case noWiFiInterface
    case networksetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .dnsChangeFailed(let msg):
            return "DNS change failed: \(msg)"
        case .noWiFiInterface:
            return "No Wi-Fi interface found"
        case .networksetupFailed(let msg):
            return "networksetup failed: \(msg)"
        }
    }
}
