import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: MappingStore
    @State private var mappings: [NetworkMapping] = []
    var onSave: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($mappings) { $mapping in
                    HStack(spacing: 8) {
                        TextField("SSID", text: $mapping.ssid)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 120)

                        Text("→")
                            .foregroundColor(.secondary)

                        TextField("DNS servers (comma-separated)", text: Binding(
                            get: { mapping.dnsServers.joined(separator: ", ") },
                            set: { mapping.dnsServers = $0
                                .components(separatedBy: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 180)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    mappings.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                addButton

                Button {
                    if !mappings.isEmpty {
                        mappings.removeLast()
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(mappings.isEmpty)

                Spacer()

                Button("Save") {
                    store.save(mappings)
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(10)
        }
        .frame(width: 500, height: 300)
        .onAppear {
            mappings = store.mappings
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if store.knownSSIDs.isEmpty {
            Button {
                mappings.append(NetworkMapping(ssid: "", dnsServers: ["192.168.1.1"]))
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        } else {
            Menu {
                ForEach(store.knownSSIDs, id: \.self) { ssid in
                    Button(ssid) {
                        mappings.append(NetworkMapping(ssid: ssid, dnsServers: ["192.168.1.1"]))
                    }
                }
                Divider()
                Button("Custom…") {
                    mappings.append(NetworkMapping(ssid: "", dnsServers: ["192.168.1.1"]))
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
