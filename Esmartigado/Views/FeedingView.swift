import SwiftUI
import Charts

struct FeedingView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var isMeasuring = false
    @State private var alarmTime = Date()
    @State private var alarmSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    racaoLevelCard
                    measureButton
                    historySection
                    alarmSection
                    herdConsumptionCard
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Alimentação")
            .task { await iotService.fetchRacao() }
            .refreshable { await iotService.fetchRacao() }
        }
    }

    // MARK: - Nível de ração (sensor)

    private var racaoLevelCard: some View {
        let leitura = iotService.ultimaRacao
        let critico = leitura?.isCritico ?? false
        let semLeitura = leitura?.semLeitura ?? true

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nível de ração")
                    .font(.headline)
                Spacer()
                statusBadge(critico: critico, semLeitura: semLeitura)
            }

            if let dist = leitura?.distanciaCm {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", dist))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(critico ? AppTheme.alertRed : AppTheme.primaryGreen)
                    Text("cm de distância")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text(critico
                     ? "Ração baixa — reabasteça o recipiente"
                     : "Nível adequado de ração")
                    .font(.caption)
                    .foregroundStyle(critico ? AppTheme.alertRed : AppTheme.textSecondary)
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

    private func statusBadge(critico: Bool, semLeitura: Bool) -> some View {
        let color = semLeitura ? AppTheme.textSecondary : (critico ? AppTheme.alertRed : AppTheme.primaryGreen)
        let text = semLeitura ? "—" : (critico ? "CRÍTICO" : "NORMAL")
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
                    ProgressView()
                        .tint(.white)
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

    // MARK: - Histórico

    @ViewBuilder
    private var historySection: some View {
        let pontos: [RacaoPonto] = iotService.historicoRacao
            .reversed()
            .compactMap { $0.distanciaCm }
            .enumerated()
            .map { RacaoPonto(indice: $0.offset, distancia: $0.element) }

        if pontos.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Histórico de leituras")
                    .font(.headline)

                Chart(pontos) { ponto in
                    LineMark(
                        x: .value("Leitura", ponto.indice),
                        y: .value("Distância (cm)", ponto.distancia)
                    )
                    .foregroundStyle(AppTheme.accentBlue)

                    PointMark(
                        x: .value("Leitura", ponto.indice),
                        y: .value("Distância (cm)", ponto.distancia)
                    )
                    .foregroundStyle(ponto.distancia > 30 ? AppTheme.alertRed : AppTheme.primaryGreen)
                }
                .frame(height: 180)

                RuleMarkLegend()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    // MARK: - Alarme

    private var alarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Horário do alarme")
                .font(.headline)

            Text("No horário definido, o sistema dispara uma medição automática todos os dias.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack {
                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
                Button("Salvar") {
                    Task {
                        await iotService.definirAlarmeRacao(hora: horaString(alarmTime))
                        alarmSaved = true
                    }
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accentBlue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let hora = iotService.horarioAlarme {
                Label("Alarme definido para \(hora)", systemImage: "alarm")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Consumo do rebanho (derivado de /animais)

    private var herdConsumptionCard: some View {
        let consumo = iotService.corralStatus?.feedConsumptionKg ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("Consumo diário do rebanho")
                .font(.headline)
            Text(String(format: "%.0f kg/dia", consumo))
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryGreen)
            Text("Soma do consumo diário de \(iotService.animais.count) animais")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func horaString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

/// Ponto do gráfico de histórico de leituras do sensor.
private struct RacaoPonto: Identifiable {
    let indice: Int
    let distancia: Double
    var id: Int { indice }
}

/// Legenda simples do gráfico de histórico.
private struct RuleMarkLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: AppTheme.primaryGreen, text: "Normal (≤ 30 cm)")
            legendItem(color: AppTheme.alertRed, text: "Crítico (> 30 cm)")
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.textSecondary)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

#Preview {
    FeedingView()
        .environmentObject(IoTService())
}
