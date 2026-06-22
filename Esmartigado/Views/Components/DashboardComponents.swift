import SwiftUI

struct OverviewCard: View {
    let metric: OverviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: metric.icon)
                .font(.title3)
                .foregroundStyle(colorFor(metric.iconColor))

            Text(metric.value)
                .font(.title.bold())

            Text(metric.label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text(metric.subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "green": return AppTheme.primaryGreen
        case "yellow": return AppTheme.accentYellow
        case "blue": return AppTheme.accentBlue
        case "purple": return AppTheme.accentPurple
        default: return .gray
        }
    }
}

struct IndicatorCard: View {
    let indicator: DailyIndicator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(indicator.title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text(indicator.value)
                .font(.title3.bold())

            if let progress = indicator.progress {
                ProgressView(value: progress)
                    .tint(AppTheme.primaryGreen)
                if let label = indicator.progressLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if let trend = indicator.trend {
                Text(trend)
                    .font(.caption2)
                    .foregroundStyle(indicator.trendUp == true ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct AlertRow: View {
    let alert: AlertItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.icon)
                .font(.title3)
                .foregroundStyle(colorFor(alert.iconColor))
                .frame(width: 36, height: 36)
                .background(colorFor(alert.iconColor).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.bold())
                Text(alert.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(alert.time)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "pink": return AppTheme.alertPink
        case "yellow": return AppTheme.accentYellow
        case "red": return AppTheme.alertRed
        default: return .gray
        }
    }
}

struct ActivityRow: View {
    let activity: ActivityItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundStyle(AppTheme.primaryGreen)

            Text(activity.description)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()

            Text(activity.time)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
