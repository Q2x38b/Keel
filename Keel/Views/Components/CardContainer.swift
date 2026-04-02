import SwiftUI

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Card Header
struct CardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let timestamp: String?
    let isOnline: Bool

    init(
        icon: String,
        iconColor: Color = .green,
        title: String,
        subtitle: String,
        timestamp: String? = nil,
        isOnline: Bool = true
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.isOnline = isOnline
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    if let timestamp = timestamp {
                        Text("|")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                        Text(timestamp)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            // Online Status
            OnlineStatusBadge(isOnline: isOnline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Online Status Badge
struct OnlineStatusBadge: View {
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isOnline {
                Image(systemName: "wifi")
                    .font(.caption2)
            }
            Text(isOnline ? "Online" : "Offline")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isOnline ? Color.statusOnline : Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isOnline ? Color.statusOnline.opacity(0.15) : Color.tertiaryBackground)
        )
    }
}

// MARK: - Card Divider
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.cardBorder)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

// MARK: - No Lesson Status Bar
struct NoLessonStatusBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.subheadline)

            Text("No Lessons Right Now")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.tertiaryBackground)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(
                    icon: "house.fill",
                    iconColor: .orange,
                    title: "Home",
                    subtitle: "Last Location",
                    timestamp: "2 hours ago",
                    isOnline: false
                )

                Rectangle()
                    .fill(Color.tertiaryBackground)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                NoLessonStatusBar()
                    .padding(.top, 12)
            }
        }
        .padding()

        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(
                    icon: "building.columns.fill",
                    iconColor: .green,
                    title: "School #15",
                    subtitle: "Current Location",
                    isOnline: true
                )

                Text("Content goes here")
                    .padding()
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding()
    }
    .background(Color.background)
    .preferredColorScheme(.dark)
}
