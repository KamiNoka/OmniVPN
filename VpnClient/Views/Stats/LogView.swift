import SwiftUI

public struct LogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var statsManager = StatsManager.shared
    @State private var searchKeyword: String = ""
    @State private var isCopied: Bool = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if filteredLogs.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Нет записей в журнале")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, log in
                                    Text(log)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(logColor(log))
                                        .textSelection(.enabled)
                                        .id(index)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .background(Color(uiColor: .black))
            .searchable(text: $searchKeyword, prompt: "Фильтр логов...")
            .navigationTitle("Журнал ядра")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let fullText = statsManager.recentLogs.joined(separator: "\n")
                        UIPasteboard.general.string = fullText
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    } label: {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }

    private var filteredLogs: [String] {
        if searchKeyword.isEmpty {
            return statsManager.recentLogs
        }
        return statsManager.recentLogs.filter { $0.localizedCaseInsensitiveContains(searchKeyword) }
    }

    private func logColor(_ log: String) -> Color {
        if log.contains("Ошибка") || log.contains("Error") || log.contains("fail") {
            return Color.red.opacity(0.9)
        } else if log.contains("успешно") || log.contains("started") || log.contains("ready") {
            return Color.green.opacity(0.9)
        } else if log.contains("warn") {
            return Color.yellow.opacity(0.9)
        }
        return Color.white.opacity(0.85)
    }
}
