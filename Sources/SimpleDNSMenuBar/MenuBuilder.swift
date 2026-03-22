import AppKit

enum MenuBuilder {
    static func build(
        currentSSID: String?,
        currentDNS: [String],
        serviceName: String,
        mappings: [NetworkMapping],
        applyMappingAction: Selector,
        preferencesAction: Selector,
        launchAtLoginEnabled: Bool?,
        launchAtLoginAction: Selector?,
        helpAction: Selector,
        quitAction: Selector,
        target: AnyObject
    ) -> NSMenu {
        let menu = NSMenu()

        // Current connection info
        let dnsLabel = currentDNS.isEmpty ? "DNS: Automatic" : "DNS: \(currentDNS.joined(separator: ", "))"

        let dnsItem = NSMenuItem(title: dnsLabel, action: nil, keyEquivalent: "")
        dnsItem.isEnabled = false
        menu.addItem(dnsItem)

        let serviceItem = NSMenuItem(title: "Service: \(serviceName)", action: nil, keyEquivalent: "")
        serviceItem.isEnabled = false
        menu.addItem(serviceItem)

        menu.addItem(.separator())

        // Configured mappings
        let autoItem = NSMenuItem(title: "Automatic (DHCP)", action: applyMappingAction, keyEquivalent: "")
        autoItem.target = target
        autoItem.representedObject = nil
        autoItem.state = currentDNS.isEmpty ? .on : .off
        menu.addItem(autoItem)

        for mapping in mappings {
            let dnsStr = mapping.dnsServers.isEmpty ? "Automatic" : mapping.dnsServers.joined(separator: ", ")
            let item = NSMenuItem(title: "\(mapping.ssid)  →  \(dnsStr)", action: applyMappingAction, keyEquivalent: "")
            item.target = target
            item.representedObject = mapping
            item.state = (!currentDNS.isEmpty && currentDNS == mapping.dnsServers) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Actions
        let prefsItem = NSMenuItem(title: "Preferences…", action: preferencesAction, keyEquivalent: ",")
        prefsItem.target = target
        menu.addItem(prefsItem)

        if let launchAtLoginAction, let enabled = launchAtLoginEnabled {
            let item = NSMenuItem(title: "Launch at Login", action: launchAtLoginAction, keyEquivalent: "")
            item.target = target
            item.state = enabled ? .on : .off
            menu.addItem(item)
        }

        let aboutItem = NSMenuItem(title: "Help", action: helpAction, keyEquivalent: "")
        aboutItem.target = target
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
