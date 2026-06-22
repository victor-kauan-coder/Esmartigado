import SwiftUI

struct HomeView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    contentSection
                }
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AppTheme.darkGreen, AppTheme.primaryGreen.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                            Circle()
                                .fill(AppTheme.alertRed)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }

                Text("Olá, \(iotService.dashboard.userName)!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Bem-vindo ao seu curral inteligente.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                    Text("\(iotService.dashboard.temperature)°C")
                        .font(.title3.bold())
                    Text(iotService.dashboard.weatherDescription)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(iotService.dashboard.location)
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding()
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            connectionBadge

            sectionTitle("Visão geral")
            overviewGrid

            sectionTitle("Indicadores do dia")
            indicatorsRow

            HStack {
                sectionTitle("Alertas importantes")
                Spacer()
                Button("Ver todos") { }
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryGreen)
            }
            alertsList

            sectionTitle("Atividades recentes")
            activitiesList
        }
        .padding()
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(iotService.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(iotService.isConnected ? "Conectado ao Node-RED" : "Modo offline — dados locais")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(iotService.dashboard.overview) { metric in
                OverviewCard(metric: metric)
            }
        }
    }

    private var indicatorsRow: some View {
        HStack(spacing: 12) {
            ForEach(iotService.dashboard.indicators) { indicator in
                IndicatorCard(indicator: indicator)
            }
        }
    }

    private var alertsList: some View {
        VStack(spacing: 8) {
            ForEach(iotService.dashboard.alerts) { alert in
                AlertRow(alert: alert)
            }
        }
    }

    private var activitiesList: some View {
        VStack(spacing: 8) {
            ForEach(iotService.dashboard.activities) { activity in
                ActivityRow(activity: activity)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

#Preview {
    HomeView()
        .environmentObject(IoTService())
}
