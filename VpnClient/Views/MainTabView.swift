import SwiftUI

public struct MainTabView: View {
    public init() {}

    public var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Главная", systemImage: "shield.checkered")
                }

            ServerListView()
                .tabItem {
                    Label("Серверы", systemImage: "network")
                }

            StatisticsView()
                .tabItem {
                    Label("Статистика", systemImage: "chart.xyaxis.line")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
        }
    }
}
