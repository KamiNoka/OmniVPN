import SwiftUI
import Charts

public struct StatisticsView: View {
    @StateObject private var statsManager = StatsManager.shared
    @StateObject private var vpnManager = VPNManager.shared
    @State private var isShowingLogs = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Real-time Traffic Graph (Swift Charts)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Скорость в реальном времени")
                                    .font(.headline)
                                Text("История за последние 60 секунд")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                    Text("DL").font(.caption2.bold()).foregroundColor(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                                    Text("UL").font(.caption2.bold()).foregroundColor(.secondary)
                                }
                            }
                        }

                        if statsManager.trafficHistory.isEmpty {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(height: 200)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "chart.xyaxis.line")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary)
                                        Text("Нет активного трафика")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                        } else {
                            Chart {
                                ForEach(statsManager.trafficHistory) { point in
                                    AreaMark(
                                        x: .value("Time", point.timestamp),
                                        y: .value("Download", point.downloadBytesPerSec / 1024)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.4), Color.green.opacity(0.02)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", point.timestamp),
                                        y: .value("Download", point.downloadBytesPerSec / 1024)
                                    )
                                    .foregroundStyle(Color.green)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", point.timestamp),
                                        y: .value("Upload", point.uploadBytesPerSec / 1024)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let speed = value.as(Double.self) {
                                            Text("\(Int(speed)) KB/s")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                    // Totals Cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Учет использования трафика")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(
                                title: "За сессию (DL)",
                                value: statsManager.currentSnapshot.sessionDownloadTotal.formattedBytes,
                                icon: "arrow.down.circle.fill",
                                color: .green
                            )

                            StatCard(
                                title: "За сессию (UL)",
                                value: statsManager.currentSnapshot.sessionUploadTotal.formattedBytes,
                                icon: "arrow.up.circle.fill",
                                color: .blue
                            )

                            StatCard(
                                title: "Всего скачано",
                                value: statsManager.currentSnapshot.totalDownloadAllTime.formattedBytes,
                                icon: "internaldrive.fill",
                                color: .purple
                            )

                            StatCard(
                                title: "Всего отдано",
                                value: statsManager.currentSnapshot.totalUploadAllTime.formattedBytes,
                                icon: "paperplane.circle.fill",
                                color: .orange
                            )
                        }
                        .padding(.horizontal)
                    }

                    // System Logs Action
                    Button {
                        isShowingLogs = true
                    } label: {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.accentColor)
                            Text("Журнал ядра (Core Logs)")
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Статистика")
            .sheet(isPresented: $isShowingLogs) {
                LogView()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
