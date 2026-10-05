import SwiftUI

public struct ServerListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedFilter: ProxyProtocol? = nil
    @State private var isPinging: Bool = false
    @State private var isShowingAddSheet: Bool = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Protocol Filter Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Все", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                        }

                        ForEach(ProxyProtocol.allCases.filter { $0 != .direct }) { proto in
                            FilterChip(title: proto.rawValue, isSelected: selectedFilter == proto) {
                                selectedFilter = proto
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemBackground))

                // Server List
                List {
                    ForEach(filteredServers) { node in
                        ServerRowView(
                            node: node,
                            isSelected: appState.selectedNodeId == node.id
                        ) {
                            appState.selectedNode = node
                        }
                    }
                    .onDelete { indexSet in
                        appState.deleteNode(at: indexSet)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, prompt: "Поиск серверов...")
            .navigationTitle("Серверы")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        handlePingAll()
                    } label: {
                        if isPinging {
                            ProgressView()
                        } else {
                            Label("Пинг", systemImage: "bolt.horizontal.circle")
                        }
                    }
                    .disabled(isPinging || appState.servers.isEmpty)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddServerSheet()
            }
        }
    }

    private var filteredServers: [ServerNode] {
        appState.servers.filter { node in
            let matchesSearch = searchText.isEmpty ||
                node.name.localizedCaseInsensitiveContains(searchText) ||
                node.server.localizedCaseInsensitiveContains(searchText) ||
                node.protocolType.rawValue.localizedCaseInsensitiveContains(searchText)

            let matchesProto = selectedFilter == nil || node.protocolType == selectedFilter

            return matchesSearch && matchesProto
        }
    }

    private func handlePingAll() {
        isPinging = true
        Task {
            await appState.pingAllServers()
            await MainActor.run {
                isPinging = false
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemFill))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
