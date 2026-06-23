import SwiftUI

struct FinancialView: View {
    @EnvironmentObject var iotService: IoTService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    revenueCard
                    costsSection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Financeiro")
        }
    }

    private var revenueCard: some View {
        let revenue = iotService.corralStatus?.monthlyRevenue ?? 18750

        return VStack(alignment: .leading, spacing: 8) {
            Text("Receita do mês")
                .font(.headline)
            Text(formatCurrency(revenue))
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryGreen)
            Label("↑ 12% em relação ao mês anterior", systemImage: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var costsSection: some View {
        let feedingCost = iotService.monthlyFeedingCost()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Custos")
                .font(.headline)

            costRow(title: "Alimentação", value: feedingCost > 0 ? feedingCost : 4230,
                    icon: "leaf.fill", color: AppTheme.accentBlue)
            costRow(title: "Sanidade", value: 1850, icon: "syringe.fill", color: AppTheme.alertPink)
            costRow(title: "Manutenção", value: 920, icon: "wrench.fill", color: AppTheme.accentYellow)
        }
    }

    private func costRow(title: String, value: Double, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(formatCurrency(value))
                .font(.subheadline.bold())
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

#Preview {
    FinancialView()
        .environmentObject(IoTService())
}
