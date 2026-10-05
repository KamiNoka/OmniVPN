import SwiftUI
import NetworkExtension

public struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var statsManager = StatsManager.shared
    @State private var isShowingServerPicker = false
    @State private var isPulsing = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Routing Mode Pill
                        HStack {
                            Label(appState.routingMode.rawValue, systemImage: "arrow.triangle.branch")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                .foregroundColor(.accentColor)

                            Spacer()

                            if vpnManager.vpnStatus == .connected {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(formatDuration(vpnManager.sessionDuration))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Central Connect / Disconnect Button with Pulse Glow
                        ZStack {
                            if vpnManager.vpnStatus == .connected {
                                Circle()
                                    .stroke(Color.green.opacity(0.25), lineWidth: 16)
                                    .frame(width: 190, height: 190)
                                    .scaleEffect(isPulsing ? 1.08 : 0.98)
                                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isPulsing)
                            } else if vpnManager.isConnecting {
                                Circle()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 16)
                                    .frame(width: 190, height: 190)
                                    .scaleEffect(isPulsing ? 1.06 : 0.98)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                            }

                            Button {
                                handleToggleVPN()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(buttonGradient)
                                        .frame(width: 150, height: 150)
                                        .shadow(color: buttonShadowColor, radius: 18, x: 0, y: 10)

                                    VStack(spacing: 8) {
                                        if vpnManager.isConnecting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.4)
                                        } else {
                                            Image(systemName: "power")
                                                .font(.system(size: 48, weight: .bold))
                                                .foregroundColor(.white)
                                        }

                                        Text(statusText)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.vertical, 16)
                        .onAppear {
                            isPulsing = true
                        }

                        // Selected Server Card
                        if let selected = appState.selectedNode {
                            Button {
                                isShowingServerPicker = true
                            } label: {
                                HStack(spacing: 16) {
                                    Text(selected.countryFlag)
                                        .font(.system(size: 36))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selected.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        HStack(spacing: 8) {
                                            Text(selected.protocolType.rawValue)
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.12))
                                                .foregroundColor(.blue)
                                                .clipShape(Capsule())

                                            if let ping = selected.pingMs {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(ping < 100 ? Color.green : (ping < 250 ? Color.orange : Color.red))
                                                        .frame(width: 6, height: 6)
                                                    Text("\(ping) ms")
                                                        .font(.caption2.weight(.medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                                )
                                .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Real-time Speed Gauges
                        HStack(spacing: 16) {
                            SpeedWidgetView(
                                title: "Входящий",
                                speedFormatted: statsManager.currentSnapshot.currentDownloadRate.formattedSpeed,
                                isDownload: true
                            )

                            SpeedWidgetView(
                                title: "Исходящий",
                                speedFormatted: statsManager.currentSnapshot.currentUploadRate.formattedSpeed,
                                isDownload: false
                            )
                        }
                        .padding(.horizontal)

                        // Session Traffic Information
                        VStack(spacing: 12) {
                            HStack {
                                Text("Трафик текущей сессии")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Загружено")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(statsManager.currentSnapshot.sessionDownloadTotal.formattedBytes)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Divider()
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Отправлено")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(statsManager.currentSnapshot.sessionUploadTotal.formattedBytes)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("OmniVPN")
            .sheet(isPresented: $isShowingServerPicker) {
                ServerListView()
            }
            .onChange(of: vpnManager.vpnStatus) { newStatus in
                if newStatus == .connected {
                    statsManager.startPolling()
                } else {
                    statsManager.stopPolling()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleToggleVPN() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if vpnManager.vpnStatus == .connected || vpnManager.isConnecting {
            vpnManager.disconnect()
        } else {
            guard let activeNode = appState.selectedNode else { return }
            guard let config = ConfigBuilder.shared.buildConfigJSON(
                selectedNode: activeNode,
                routingMode: appState.routingMode,
                customRules: appState.customRules,
                dnsServer: appState.dnsServer
            ) else {
                return
            }

            Task {
                do {
                    try await vpnManager.connect(configJSON: config)
                } catch {
                    print("Error connecting VPN: \(error)")
                }
            }
        }
    }

    // MARK: - UI Helpers

    private var statusText: String {
        switch vpnManager.vpnStatus {
        case .connected: return "ПОДКЛЮЧЕНО"
        case .connecting, .reasserting: return "СОЕДИНЕНИЕ"
        case .disconnecting: return "ОТКЛЮЧЕНИЕ"
        default: return "НАЖМИТЕ"
        }
    }

    private var buttonGradient: LinearGradient {
        switch vpnManager.vpnStatus {
        case .connected:
            return LinearGradient(
                colors: [Color(hex: "10B981"), Color(hex: "059669")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting, .reasserting:
            return LinearGradient(
                colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(hex: "4B5563"), Color(hex: "374151")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var buttonShadowColor: Color {
        switch vpnManager.vpnStatus {
        case .connected: return Color(hex: "10B981").opacity(0.4)
        case .connecting, .reasserting: return Color(hex: "F59E0B").opacity(0.4)
        default: return Color.black.opacity(0.15)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
