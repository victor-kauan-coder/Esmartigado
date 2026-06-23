import SwiftUI
import Charts

struct FeedingView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var isMeasuring = false
    @State private var periodo: PeriodoConsumo = .semana

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCards
                    levelCard
                    measureButton
                    consumoSection
                    managementLinks
                    historySection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Alimentação")
            .task { await loadAll() }
            .refreshable { await loadAll() }
        }
    }

    private func loadAll() async {
        await iotService.fetchRacao()
        await iotService.fetchConfig()
        await iotService.fetchConsumo(periodo: periodo)
    }

    // MARK: - Cards de percentual e peso

    private var statusCards: some View {
        let leitura = iotService.ultimaRacao
        return HStack(spacing: 12) {
            metricCard(
                title: "Nível de ração",
                value: percentualText(leitura),
                icon: "chart.bar.fill",
                color: percentualColor(leitura)
            )
            metricCard(
                title: "Peso estimado",
                value: pesoText(leitura),
                icon: "scalemass.fill",
                color: AppTheme.accentBlue
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Card de nível/distância

    private var levelCard: some View {
        let leitura = iotService.ultimaRacao
        let critico = leitura?.isCritico ?? false
        let semLeitura = leitura?.semLeitura ?? true
        let foraAlcance = leitura?.foraDeAlcance ?? false

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sensor")
                    .font(.headline)
                Spacer()
                statusBadge(critico: critico, semLeitura: semLeitura, foraAlcance: foraAlcance)
            }

            if foraAlcance {
                Text("Sensor fora de alcance")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.alertRed)
                Text("Verifique o posicionamento do sensor no recipiente")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if let dist = leitura?.distanciaCm {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", dist))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(critico ? AppTheme.alertRed : AppTheme.primaryGreen)
                    Text("cm de distância")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if leitura?.semConfiguracao == true {
                    Text("Calibre o recipiente para ver o percentual e o peso")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentYellow)
                }
            } else {
                Text("Sem medição ainda")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Toque em \"Medir agora\" para ler o sensor")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let hora = leitura?.hora {
                Label("Última leitura às \(hora)", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func statusBadge(critico: Bool, semLeitura: Bool, foraAlcance: Bool) -> some View {
        let color: Color
        let text: String
        if semLeitura || foraAlcance {
            color = AppTheme.textSecondary
            text = "—"
        } else if critico {
            color = AppTheme.alertRed
            text = "CRÍTICO"
        } else {
            color = AppTheme.primaryGreen
            text = "NORMAL"
        }
        return Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var measureButton: some View {
        Button {
            Task {
                isMeasuring = true
                await iotService.medirRacao()
                isMeasuring = false
            }
        } label: {
            HStack {
                if isMeasuring {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "ruler")
                }
                Text(isMeasuring ? "Medindo..." : "Medir agora")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.primaryGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isMeasuring)
    }

    // MARK: - Consumo

    private var consumoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consumo de ração")
                    .font(.headline)
                Spacer()
                if let total = iotService.consumo?.total {
                    Text(String(format: "%.1f kg", total))
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.primaryGreen)
                }
            }

            Picker("Período", selection: $periodo) {
                ForEach(PeriodoConsumo.allCases) { p in
                    Text(p.titulo).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: periodo) { _, novo in
                Task { await iotService.fetchConsumo(periodo: novo) }
            }

            let dias = iotService.consumo?.consumoPorDia ?? []
            if dias.isEmpty {
                Text("Sem dados de consumo no período")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(dias) { dia in
                    BarMark(
                        x: .value("Dia", dia.data),
                        y: .value("Consumo (kg)", dia.consumo)
                    )
                    .foregroundStyle(AppTheme.primaryGreen)
                }
                .frame(height: 180)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Links de gestão

    private var managementLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                RacaoConfigView()
            } label: {
                linkRow(icon: "slider.horizontal.3", title: "Configuração do recipiente",
                        subtitle: iotService.configRecipiente?.configurado == true ? "Calibrado" : "Não calibrado")
            }
            Divider().padding(.leading, 52)
            NavigationLink {
                AlarmesView()
            } label: {
                linkRow(icon: "alarm", title: "Alarmes de medição",
                        subtitle: "\(iotService.alarmes.count) horário(s)")
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
    }

    // MARK: - Histórico

    @ViewBuilder
    private var historySection: some View {
        let leituras = iotService.historicoRacao
        if !leituras.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Histórico de leituras")
                    .font(.headline)

                ForEach(leituras.prefix(15)) { leitura in
                    HStack {
                        Circle()
                            .fill(leitura.isCritico ? AppTheme.alertRed : AppTheme.primaryGreen)
                            .frame(width: 8, height: 8)
                        Text(leitura.hora ?? "—")
                            .font(.caption)
                        Spacer()
                        if let p = leitura.percentualRacao {
                            Text(String(format: "%.0f%%", p))
                                .font(.caption.bold())
                        }
                        if let d = leitura.distanciaCm {
                            Text(String(format: "%.0f cm", d))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Formatação

    private func percentualText(_ l: RacaoLeitura?) -> String {
        guard let p = l?.percentualRacao else { return "—" }
        return String(format: "%.0f%%", p)
    }

    private func percentualColor(_ l: RacaoLeitura?) -> Color {
        guard let p = l?.percentualRacao else { return AppTheme.textSecondary }
        if p <= 15 { return AppTheme.alertRed }
        if p <= 40 { return AppTheme.accentYellow }
        return AppTheme.primaryGreen
    }

    private func pesoText(_ l: RacaoLeitura?) -> String {
        guard let kg = l?.pesoKg else { return "—" }
        return String(format: "%.1f kg", kg)
    }
}

#Preview {
    FeedingView()
        .environmentObject(IoTService())
}
