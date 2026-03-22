import Foundation

enum NetworkServiceResolver {
    /// Parses `networksetup -listnetworkserviceorder` to map BSD interface name → service name.
    /// Example output:
    ///   (1) Wi-Fi
    ///   (Hardware Port: Wi-Fi, Device: en0)
    static func resolveServiceName(for interfaceName: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listnetworkserviceorder"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // Parse lines in pairs: service name line followed by hardware port line
        let lines = output.components(separatedBy: .newlines)
        var currentServiceName: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Service name line: "(1) Wi-Fi"
            if trimmed.hasPrefix("(") && !trimmed.hasPrefix("(Hardware") {
                // Extract service name after "(N) "
                if let parenClose = trimmed.firstIndex(of: ")") {
                    let afterParen = trimmed.index(after: parenClose)
                    if afterParen < trimmed.endIndex {
                        currentServiceName = String(trimmed[afterParen...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            // Hardware port line: "(Hardware Port: Wi-Fi, Device: en0)"
            else if trimmed.hasPrefix("(Hardware Port:"), let serviceName = currentServiceName {
                // Extract device name
                if let deviceRange = trimmed.range(of: "Device: ") {
                    let afterDevice = deviceRange.upperBound
                    let deviceSubstring = trimmed[afterDevice...]
                    let device = deviceSubstring
                        .components(separatedBy: CharacterSet(charactersIn: ",)"))
                        .first?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    if device == interfaceName {
                        return serviceName
                    }
                }
                currentServiceName = nil
            }
        }

        return nil
    }
}
