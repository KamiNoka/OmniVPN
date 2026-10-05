import SwiftUI

public struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var inputText: String = ""
    @State private var subscriptionName: String = "Моя подписка"
    @State private var isShowingScanner: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Импорт конфигурации или подписки")) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("Вставьте ссылку vless://, hysteria2://, trojan://, ss://, vmess://, URL подписки или Sing-box JSON...")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        Button {
                            if let clip = UIPasteboard.general.string {
                                inputText = clip
                            }
                        } label: {
                            Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                        }

                        Spacer()

                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("QR-код", systemImage: "qrcode.viewfinder")
                        }
                    }
                }

                if isSubscriptionURL(inputText) {
                    Section(header: Text("Параметры подписки")) {
                        TextField("Название подписки", text: $subscriptionName)
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        handleImport()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Импортировать")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .navigationTitle("Добавить сервер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerView { scannedCode in
                    self.inputText = scannedCode
                }
            }
        }
    }

    private func isSubscriptionURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    private func handleImport() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        if isSubscriptionURL(trimmed) {
            // Fetch subscription from network
            guard let url = URL(string: trimmed) else {
                errorMessage = "Неверный формат URL"
                return
            }

            isLoading = true
            Task {
                do {
                    var request = URLRequest(url: url)
                    request.setValue("sing-box/1.9.0", forHTTPHeaderField: "User-Agent")
                    request.timeoutInterval = 15.0

                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode),
                          let content = String(data: data, encoding: .utf8) else {
                        throw NSError(domain: "Network", code: -1, userInfo: [NSLocalizedDescriptionKey: "Сбой загрузки подписки"])
                    }

                    await MainActor.run {
                        appState.addSubscription(name: subscriptionName, url: trimmed, content: content)
                        isLoading = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Не удалось загрузить подписку: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Parse local text / JSON / URI
            let nodes = SubscriptionParser.shared.parse(content: trimmed)
            if nodes.isEmpty {
                errorMessage = "Не удалось распознать серверы из введенного текста"
            } else {
                for node in nodes {
                    appState.addNode(node)
                }
                dismiss()
            }
        }
    }
}
