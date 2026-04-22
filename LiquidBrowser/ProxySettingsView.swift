import SwiftUI

struct ProxySettingsView: View {
    @ObservedObject var viewModel: BrowserViewModel

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "8080"
    @State private var type: ProxyKind = .httpConnect
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved proxies") {
                    if viewModel.proxies.isEmpty {
                        Text("No proxies yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.proxies) { proxy in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(proxy.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(proxy.type.rawValue)  |  \(proxy.host):\(proxy.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.activeProxyID == proxy.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Use") {
                                        viewModel.setActiveProxy(proxy.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .onDelete(perform: viewModel.removeProxy)
                    }
                }

                Section("Add proxy") {
                    TextField("Name", text: $name)
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)

                    Picker("Type", selection: $type) {
                        ForEach(ProxyKind.allCases) { proxyType in
                            Text(proxyType.rawValue).tag(proxyType)
                        }
                    }

                    TextField("Username (optional)", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    SecureField("Password (optional)", text: $password)

                    Button("Save proxy") {
                        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        guard let parsedPort = Int(port), parsedPort > 0, parsedPort < 65536 else { return }

                        viewModel.addProxy(
                            name: name,
                            host: host,
                            port: parsedPort,
                            type: type,
                            username: username,
                            password: password
                        )

                        name = ""
                        host = ""
                        port = "8080"
                        type = .httpConnect
                        username = ""
                        password = ""
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Proxy rotation") {
                    Toggle("Rotate if proxy fails", isOn: Binding(
                        get: { viewModel.settings.rotateProxyOnFailure },
                        set: { viewModel.toggleProxyRotation($0) }
                    ))

                    Button("Switch to next proxy now") {
                        viewModel.rotateProxyAndRebuild()
                    }
                    .disabled(viewModel.proxies.count < 2)
                }
            }
            .navigationTitle("Proxy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.isShowingProxyEditor = false
                    }
                }
            }
        }
    }
}
