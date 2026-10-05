import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingResetAlert = false

    private let dnsOptions = [
        ("Cloudflare DoH", "https://1.1.1.1/dns-query"),
        ("Google DoH", "https://dns.google/dns-query"),
        ("Quad9 DoH", "https://dns.quad9.net/dns-query"),
        ("AdGuard DNS (Рекламоблокатор)", "https://dns.adguard-dns.com/dns-query")
    ]

    public var body: some View {
        NavigationStack {
            Form {
                // Routing Mode Section
                Section(
                    header: Text("Режим маршрутизации"),
                    footer: Text(appState.routingMode.description)
                ) {
                    Picker("Маршрутизация", selection: $appState.routingMode) {
                        ForEach(RoutingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: appState.routingMode) { _ in
                        appState.saveSettings()
                    }
                }

                // DNS Configuration
                Section(header: Text("Безопасный DNS (DoH)")) {
                    Picker("DNS сервер", selection: $appState.dnsServer) {
                        ForEach(dnsOptions, id: \.1) { name, url in
                            Text(name).tag(url)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: appState.dnsServer) { _ in
                        appState.saveSettings()
                    }

                    TextField("Пользовательский DoH URL", text: $appState.dnsServer)
                        .font(.caption)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Security & Switches
                Section(
                    header: Text("Безопасность"),
                    footer: Text("При включении Kill Switch интернет блокируется при непредвиденном разрыве туннеля.")
                ) {
                    Toggle("Kill Switch (Аварийный выключатель)", isOn: $appState.killSwitch)
                        .onChange(of: appState.killSwitch) { _ in
                            appState.saveSettings()
                        }
                }

                // Core & App Info
                Section(header: Text("О программе")) {
                    HStack {
                        Text("Версия клиента")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Ядро")
                        Spacer()
                        Text("Sing-box v1.9 (Libbox)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Поддерживаемые протоколы")
                        Spacer()
                        Text("VLESS, Hy2, WG, SS, Trojan, VMess")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        isShowingResetAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Сбросить все серверы и настройки")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .alert("Сбросить настройки?", isPresented: $isShowingResetAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                    appState.servers.removeAll()
                    appState.selectedNodeId = nil
                }
            } message: {
                Text("Все сохраненные конфигурации и статистика будут удалены.")
            }
        }
    }
}
