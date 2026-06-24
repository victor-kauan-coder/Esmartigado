import SwiftUI
import Charts

struct FeedingView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var isMeasuring = false
    @State private var periodo: PeriodoConsumo = .semana
    @State private var showBlockAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    presenceBanner
                    statusCards
                    levelCard
                    measureButton
                    consumoSection
                    previsaoSection
                    managementLinks
                    historySection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Alimentação")
            .task { await loadAll() }
            .refreshable { await loadAll() }
            .alert("Medição bloqueada", isPresented: $showBlockAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(iotService.presencaGado?.mensagemUI
                     ?? "Gado detectado próximo ao recipiente. Tente novamente em instantes.")
            }
        }
    }

    @ViewBuilder
    private var presenceBanner: some View {
        if let presenca = iotService.presencaGado, presenca.presenca {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.accentYellow)
                Text(presenca.mensagemUI)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.accentYellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func loadAll() async {
        await iotService.fetchRacao()
        await iotService.fetchConfig()
        await iotService.fetchConsumo(periodo: periodo)
        await iotService.fetchPrevisao()
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
        let bloqueado = leitura?.isBloqueado ?? false
        let semLeitura = leitura?.semLeitura ?? true
        let foraAlcance = leitura?.foraDeAlcance ?? false
        let nivel = leitura?.nivel ?? .normal

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sensor")
                    .font(.headline)
                Spacer()
                statusBadge(nivel: nivel, semLeitura: semLeitura, foraAlcance: foraAlcance, bloqueado: bloqueado)
            }

            if bloqueado {
                Label("Medição bloqueada", systemImage: "nosign")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accentYellow)
                Text(leitura?.motivoBloqueioTexto
                     ?? "Gado detectado próximo ao recipiente. Medição de ração indisponível.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if foraAlcance {
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
                        .foregroundStyle(nivelColor(nivel))
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

    private func statusBadge(nivel: RacaoLeitura.Nivel, semLeitura: Bool, foraAlcance: Bool, bloqueado: Bool) -> some View {
        let color: Color
        let text: String
        if bloqueado {
            color = AppTheme.accentYellow
            text = "BLOQUEADO"
        } else if semLeitura || foraAlcance {
            color = AppTheme.textSecondary
            text = "—"
        } else {
            color = nivelColor(nivel)
            switch nivel {
            case .critico: text = "CRÍTICO"
            case .baixo: text = "BAIXO"
            case .normal: text = "NORMAL"
            }
        }
        return Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func nivelColor(_ nivel: RacaoLeitura.Nivel) -> Color {
        switch nivel {
        case .critico: return AppTheme.alertRed
        case .baixo: return AppTheme.accentYellow
        case .normal: return AppTheme.primaryGreen
        }
    }

    private var measureButton: some View {
        let bloqueado = iotService.presencaGado?.presenca == true
        return Button {
            Task {
                isMeasuring = true
                let ok = await iotService.medirRacaoSeguro()
                isMeasuring = false
                if !ok { showBlockAlert = true }
            }
        } label: {
            HStack {
                if isMeasuring {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: bloqueado ? "nosign" : "ruler")
                }
                Text(isMeasuring ? "Medindo..." : (bloqueado ? "Indisponível (gado presente)" : "Medir agora"))
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(bloqueado ? AppTheme.textSecondary : AppTheme.primaryGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isMeasuring || bloqueado)
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

            consumoChart
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var consumoChart: some View {
        let dias = iotService.consumo?.consumoPorDia ?? []
        let pontos = dias.filter { $0.dataDate != nil }

        if dias.isEmpty {
            Text("Sem dados de consumo no período")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else if pontos.isEmpty {
            // Fallback categórico se as datas não forem reconhecidas.
            Chart(dias) { dia in
                BarMark(
                    x: .value("Dia", dia.label),
                    y: .value("Consumo (kg)", dia.consumo)
                )
                .foregroundStyle(AppTheme.primaryGreen)
                .cornerRadius(4)
            }
            .frame(height: 200)
        } else {
            Chart(pontos) { dia in
                BarMark(
                    x: .value("Dia", dia.dataDate ?? Date(), unit: .day),
                    y: .value("Consumo (kg)", dia.consumo)
                )
                .foregroundStyle(AppTheme.primaryGreen)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideDias)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let kg = value.as(Double.self) {
                            Text("\(kg, specifier: "%.0f") kg")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }

    /// Espaçamento dos rótulos do eixo X conforme o período.
    private var strideDias: Int {
        switch periodo {
        case .dia: return 1
        case .semana: return 1
        case .mes: return 5
        }
    }

    // MARK: - Previsão de consumo

    @ViewBuilder
    private var previsaoSection: some View {
        if let p = iotService.previsao, p.temDados {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Previsão de consumo")
                        .font(.headline)
                    Spacer()
                    tendenciaBadge(p)
                }

                Text("Média de \(fmt(p.mediaDiariaKg)) kg/dia · base de \(p.diasConsiderados) dia(s) · regressão + sazonalidade")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    previsaoCard(
                        titulo: "Semana atual",
                        valor: p.previsaoSemanaAtualKg,
                        detalhe: "já consumido \(fmt(p.consumidoSemanaAtualKg)) kg"
                    )
                    previsaoCard(
                        titulo: "Próxima semana",
                        valor: p.previsaoProximaSemanaKg,
                        detalhe: "estimativa"
                    )
                }

                if p.previsaoProximosDias.contains(where: { $0.consumo > 0 }) {
                    Text("Projeção dos próximos 7 dias")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    Chart(p.previsaoProximosDias) { dia in
                        BarMark(
                            x: .value("Dia", dia.dataDate ?? Date(), unit: .day),
                            y: .value("Previsto (kg)", dia.consumo)
                        )
                        .foregroundStyle(AppTheme.accentBlue.opacity(0.7))
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                        }
                    }
                    .frame(height: 140)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private func tendenciaBadge(_ p: PrevisaoConsumo) -> some View {
        let (texto, icone, cor): (String, String, Color)
        switch p.tendencia {
        case .crescente: (texto, icone, cor) = ("Subindo", "arrow.up.right", AppTheme.alertRed)
        case .decrescente: (texto, icone, cor) = ("Caindo", "arrow.down.right", AppTheme.primaryGreen)
        case .estavel: (texto, icone, cor) = ("Estável", "arrow.right", AppTheme.textSecondary)
        }
        return Label("\(texto) (\(fmt(abs(p.tendenciaKgPorDia))) kg/dia)", systemImage: icone)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(cor.opacity(0.15))
            .foregroundStyle(cor)
            .clipShape(Capsule())
    }

    private func previsaoCard(titulo: String, valor: Double, detalhe: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text("\(fmt(valor)) kg")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.primaryGreen)
            Text(detalhe)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.primaryGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }

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
                            .fill(nivelColor(leitura.nivel))
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
        if p <= 30 { return AppTheme.accentYellow }
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
