import SwiftUI

struct FeedingView: View {
    @EnvironmentObject var iotService: IoTService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    feedSummaryCard
                    scheduleSection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Alimentação")
        }
    }

    private var feedSummaryCard: some View {
        let consumption = iotService.corralStatus?.feedConsumptionKg ?? 1250
        let goal = iotService.corralStatus?.feedGoalKg ?? 1470
        let progress = goal > 0 ? consumption / goal : 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Consumo hoje")
                .font(.headline)
            Text(String(format: "%.0f kg", consumption))
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryGreen)
            ProgressView(value: progress)
                .tint(AppTheme.primaryGreen)
            Text(String(format: "%.0f%% da meta diária (%.0f kg)", progress * 100, goal))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Horários programados")
                .font(.headline)

            ForEach(["06:00 — Ração matinal", "12:00 — Suplemento", "18:00 — Ração noturna"], id: \.self) { item in
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AppTheme.accentBlue)
                    Text(item)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    FeedingView()
        .environmentObject(IoTService())
}
