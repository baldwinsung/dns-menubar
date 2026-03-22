import Foundation
import CoreWLAN

protocol WiFiMonitorDelegate: AnyObject {
    func wifiMonitor(_ monitor: WiFiMonitor, ssidChangedTo ssid: String?)
}

final class WiFiMonitor: NSObject, CWEventDelegate {
    weak var delegate: WiFiMonitorDelegate?
    private let client: CWWiFiClient

    override init() {
        client = CWWiFiClient.shared()
        super.init()
        client.delegate = self
    }

    func start() throws {
        try client.startMonitoringEvent(with: .ssidDidChange)
    }

    func stop() {
        try? client.stopMonitoringAllEvents()
    }

    func currentSSID(for interfaceName: String? = nil) -> String? {
        let iface = interfaceName ?? (client.interface()?.interfaceName ?? "en0")
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = ["-getairportnetwork", iface]
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let prefix = "Current Wi-Fi Network: "
        guard output.hasPrefix(prefix) else { return nil }
        return String(output.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - CWEventDelegate

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        let ssid = currentSSID(for: interfaceName)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.wifiMonitor(self, ssidChangedTo: ssid)
        }
    }
}
