import SwiftUI

public struct SpeedWidgetView: View {
    public let title: String
    public let speedFormatted: String
    public let isDownload: Bool

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDownload ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: isDownload ? "arrow.down" : "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isDownload ? .green : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(speedFormatted)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
