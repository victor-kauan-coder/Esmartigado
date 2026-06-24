import SwiftUI

struct HomeView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection(topInset: proxy.safeAreaInsets.top)
                        contentSection
                    }
                }
                .background(AppTheme.background)
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
    }

    private func headerSection(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AppTheme.darkGreen, AppTheme.primaryGreen.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Estende o gradiente sob a status bar/notch, preenchendo o topo.
            .frame(height: 220 + topInset)

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

            if iotService.corralStatus == nil && iotService.lastError != nil {
                offlineState
            } else if iotService.corralStatus == nil {
                loadingState
            } else if iotService.animais.isEmpty {
                emptyState
            } else {
                sectionTitle("Visão geral")
                overviewGrid

                sectionTitle("Indicadores do dia")
                indicatorsRow

                if !iotService.dashboard.alerts.isEmpty {
                    sectionTitle("Alertas importantes")
                    alertsList
                }

                if !iotService.dashboard.activities.isEmpty {
                    sectionTitle("Atividades recentes")
                    activitiesList
                }
            }
        }
        .padding()
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Carregando dados do rebanho...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var offlineState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Sem conexão com o servidor")
                .font(.headline)
            Text("Não foi possível carregar os dados do rebanho. Verifique se o Node-RED está acessível na rede.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nenhum animal cadastrado")
                .font(.headline)
            Text("Cadastre animais para ver os indicadores do rebanho aqui.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(iotService.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(iotService.isConnected ? "Conectado ao Node-RED" : "Sem conexão com o Node-RED")
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
