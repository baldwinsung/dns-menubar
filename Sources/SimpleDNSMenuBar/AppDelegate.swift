import AppKit
import CoreWLAN

final class AppDelegate: NSObject, NSApplicationDelegate, WiFiMonitorDelegate {
    private var statusItem: NSStatusItem!
    private var wifiMonitor: WiFiMonitor!
    private let store = MappingStore()

    private var currentSSID: String?
    private var currentDNS: [String] = []
    private var wifiServiceName: String = "Wi-Fi"
    private var wifiInterfaceName: String = "en0"

    private var preferencesWindowController: PreferencesWindowController?

    private var startupRetryCount = 0
    private let maxStartupRetries = 3

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "DNS")
        }

        // Resolve Wi-Fi interface and service name
        let interfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
        wifiInterfaceName = interfaceName
        if let resolved = NetworkServiceResolver.resolveServiceName(for: interfaceName) {
            wifiServiceName = resolved
        }

        // Get current SSID
        wifiMonitor = WiFiMonitor()
        currentSSID = wifiMonitor.currentSSID(for: wifiInterfaceName)
        if let ssid = currentSSID { store.recordSSID(ssid) }

        // Apply DNS for current SSID and build initial menu
        applyDNS()
        rebuildMenu()

        if currentSSID == nil {
            scheduleStartupRetry()
        }

        // Start monitoring
        wifiMonitor.delegate = self
        try? wifiMonitor.start()
    }

    // MARK: - Startup Retry

    private func scheduleStartupRetry() {
        guard startupRetryCount < maxStartupRetries else { return }
        startupRetryCount += 1
        let delay = Double(startupRetryCount) * 2.0   // 2s, 4s, 6s
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let ssid = self.wifiMonitor.currentSSID(for: self.wifiInterfaceName)
            guard let ssid else {
                self.scheduleStartupRetry()
                return
            }
            self.currentSSID = ssid
            self.store.recordSSID(ssid)
            self.applyDNS()
            self.rebuildMenu()
        }
    }

    // MARK: - WiFiMonitorDelegate

    func wifiMonitor(_ monitor: WiFiMonitor, ssidChangedTo ssid: String?) {
        currentSSID = ssid
        if let ssid { store.recordSSID(ssid) }
        applyDNS()
        rebuildMenu()
    }

    // MARK: - DNS Application

    private func applyDNS() {
        let servers = currentSSID.flatMap { store.mapping(forSSID: $0) }?.dnsServers ?? []
        currentDNS = servers
        let serviceName = wifiServiceName

        Task.detached {
            do {
                try DNSManager.setDNS(servers: servers, serviceName: serviceName)
            } catch {
                print("DNS change failed: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.statusItem.button?.toolTip = "DNS change failed: \(error.localizedDescription)"
                    let alert = NSAlert()
                    alert.messageText = "DNS Change Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let launchAtLoginEnabled: Bool?
        if #available(macOS 13, *) {
            launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled
        } else {
            launchAtLoginEnabled = nil
        }
        let menu = MenuBuilder.build(
            currentSSID: currentSSID,
            currentDNS: currentDNS,
            serviceName: wifiServiceName,
            mappings: store.mappings,
            applyMappingAction: #selector(applyMapping),
            preferencesAction: #selector(openPreferences),
            launchAtLoginEnabled: launchAtLoginEnabled,
            launchAtLoginAction: #selector(toggleLaunchAtLogin),
            helpAction: #selector(openHelp),
            quitAction: #selector(quit),
            target: self
        )
        statusItem.menu = menu
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13, *) else { return }
        let mgr = LaunchAtLoginManager.shared
        try? mgr.setEnabled(!mgr.isEnabled)
        rebuildMenu()
    }

    @objc private func applyMapping(_ sender: NSMenuItem) {
        let mapping = sender.representedObject as? NetworkMapping
        let servers = mapping?.dnsServers ?? []
        currentDNS = servers
        rebuildMenu()
        let serviceName = wifiServiceName
        Task.detached {
            do {
                try DNSManager.setDNS(servers: servers, serviceName: serviceName)
            } catch {
                print("DNS change failed: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.statusItem.button?.toolTip = "DNS change failed: \(error.localizedDescription)"
                    let alert = NSAlert()
                    alert.messageText = "DNS Change Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Window Actions

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(store: store) { [weak self] in
                self?.applyDNS()
                self?.rebuildMenu()
            }
        }
        preferencesWindowController?.showWindow(nil)
    }

    @objc private func openHelp() {
        NSWorkspace.shared.open(URL(string: "https://github.com/baldwinsung")!)
    }
}
