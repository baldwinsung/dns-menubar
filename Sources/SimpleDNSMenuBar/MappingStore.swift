import Foundation
import Combine

final class MappingStore: ObservableObject {
    @Published var mappings: [NetworkMapping] = []
    @Published var knownSSIDs: [String] = []

    private let key = "networkMappings"
    private let ssidKey = "knownSSIDs"

    init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([NetworkMapping].self, from: data) {
            mappings = decoded
        }
        knownSSIDs = UserDefaults.standard.stringArray(forKey: ssidKey) ?? []
    }

    func recordSSID(_ ssid: String) {
        guard !ssid.isEmpty, !knownSSIDs.contains(ssid) else { return }
        knownSSIDs.insert(ssid, at: 0)
        if knownSSIDs.count > 20 { knownSSIDs.removeLast() }
        UserDefaults.standard.set(knownSSIDs, forKey: ssidKey)
    }

    func save(_ newMappings: [NetworkMapping]) {
        mappings = newMappings
        if let data = try? JSONEncoder().encode(newMappings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func mapping(forSSID ssid: String) -> NetworkMapping? {
        mappings.first { $0.ssid == ssid }
    }
}
