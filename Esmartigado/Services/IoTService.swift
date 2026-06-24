import Foundation
import Combine

/// Configuração de conexão com o Node-RED
enum IoTConfig {
    /// URL base do Node-RED (ajuste para o IP da máquina onde ele roda)
    static let baseURL = "http://192.168.128.65:1880"
}

@MainActor
final class IoTService: ObservableObject {
    @Published var animais: [Animal] = []
    @Published var corralStatus: CorralStatus?
    @Published var dashboard: DashboardData = .empty
    @Published var isConnected = false
    @Published var lastError: String?

    // Estado do sensor de ração (flow "Sensor de Ração")
    @Published var ultimaRacao: RacaoLeitura?
    @Published var historicoRacao: [RacaoLeitura] = []
    @Published var alarmes: [String] = []
    @Published var configRecipiente: ConfigRecipiente?
    @Published var consumo: ConsumoResponse?
    @Published var previsao: PrevisaoConsumo?
    @Published var presencaGado: PresencaGado?

    private let api = AnimaisAPI()
    private let racaoAPI = RacaoAPI()
    private var pollingTimer: Timer?
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - REST API (/animais)

    func fetchAnimais() async {
        do {
            let lista = try await api.listar()
            animais = lista
            let status = makeCorralStatus(from: lista)
            corralStatus = status
            dashboard = mapToDashboard(status)
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
        }
    }

    func criarAnimal(nome: String, raca: String, idade: Int, sexo: String,
                     pesoAtual: Double, consumoDiario: Double,
                     custoAlimentacao: Double, valorMercado: Double) async {
        let body: [String: Any] = [
            "nome": nome, "raca": raca, "idade": idade, "sexo": sexo,
            "pesoAtual": pesoAtual, "consumoDiario": consumoDiario,
            "custoAlimentacao": custoAlimentacao, "valorMercado": valorMercado
        ]
        do {
            try await api.criar(animal: body)
            await fetchAnimais()
        } catch {
            lastError = "Erro ao criar: \(error.localizedDescription)"
        }
    }

    func atualizarAnimal(_ animal: Animal) async {
        do {
            try await api.atualizar(animal: animal)
            await fetchAnimais()
        } catch {
            lastError = "Erro ao atualizar: \(error.localizedDescription)"
        }
    }

    func deletarAnimal(id: Int) async {
        do {
            try await api.deletar(id: id)
            await fetchAnimais()
        } catch {
            lastError = "Erro ao deletar: \(error.localizedDescription)"
        }
    }

    /// Compatibilidade com a TrackingView. A API de animais não expõe
    /// dados de sensores/zonas, portanto retorna o que houver em cache.
    func fetchSensors() async -> [ZoneStatus] {
        corralStatus?.zones ?? []
    }

    // MARK: - Sensor de ração

    func fetchRacao() async {
        // Tenta a resposta enriquecida (leitura + presença); cai para o
        // formato antigo se o backend ainda não expõe presença.
        if let resposta = try? await racaoAPI.ultimaLeituraComPresenca() {
            ultimaRacao = resposta.leitura
            presencaGado = resposta.presenca_gado
        } else if let leitura = try? await racaoAPI.ultimaLeitura() {
            ultimaRacao = leitura
        }

        if let lista = try? await racaoAPI.historico() {
            historicoRacao = lista
        }
    }

    /// Busca apenas o estado de presença (polling rápido opcional).
    func fetchPresenca() async {
        if let estado = try? await racaoAPI.presencaGado() {
            presencaGado = estado
        }
    }

    /// Solicita uma nova medição e atualiza a leitura logo em seguida.
    func medirRacao() async {
        do {
            try await racaoAPI.medir()
            // A placa responde de forma assíncrona via WebSocket; aguarda
            // um instante antes de buscar a leitura atualizada.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await fetchRacao()
        } catch {
            lastError = "Erro ao medir: \(error.localizedDescription)"
        }
    }

    /// Solicita medição com guarda de presença: se houver gado próximo,
    /// bloqueia o comando e retorna `false`.
    @discardableResult
    func medirRacaoSeguro() async -> Bool {
        await fetchPresenca()
        if presencaGado?.presenca == true {
            lastError = presencaGado?.mensagemUI
            return false
        }
        await medirRacao()
        return true
    }

    // MARK: Alarmes

    func fetchAlarmes() async {
        if let lista = try? await racaoAPI.listarAlarmes() {
            alarmes = lista
        }
    }

    @discardableResult
    func adicionarAlarme(hora: String) async -> Bool {
        do {
            try await racaoAPI.adicionarAlarme(hora: hora)
            await fetchAlarmes()
            return true
        } catch {
            lastError = "Erro ao adicionar alarme: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func removerAlarme(hora: String) async -> Bool {
        do {
            try await racaoAPI.removerAlarme(hora: hora)
            await fetchAlarmes()
            return true
        } catch {
            lastError = "Erro ao remover alarme: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Configuração do recipiente

    func fetchConfig() async {
        if let config = try? await racaoAPI.obterConfig() {
            configRecipiente = config
        }
    }

    func salvarConfig(distanciaVazioCm: Double, distanciaCheioCm: Double, capacidadeKg: Double) async {
        do {
            try await racaoAPI.salvarConfig(distanciaVazioCm: distanciaVazioCm,
                                            distanciaCheioCm: distanciaCheioCm,
                                            capacidadeKg: capacidadeKg)
            await fetchConfig()
            await fetchRacao()
        } catch {
            lastError = "Erro ao salvar configuração: \(error.localizedDescription)"
        }
    }

    // MARK: Consumo

    func fetchConsumo(periodo: PeriodoConsumo) async {
        if let resp = try? await racaoAPI.consumo(periodo: periodo) {
            consumo = resp
        }
    }

    /// Recalcula a previsão de consumo usando os últimos 30 dias como base,
    /// independentemente do período exibido no gráfico.
    func fetchPrevisao() async {
        if let resp = try? await racaoAPI.consumo(periodo: .mes) {
            previsao = PrevisaoConsumo.calcular(de: resp.consumoPorDia)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAnimais()
                await self?.fetchRacao()
                await self?.fetchPresenca()
            }
        }
        Task {
            await fetchAnimais()
            await fetchRacao()
            await fetchPresenca()
        }
    }

    // MARK: - Derivação dos dados a partir dos animais

    /// Constrói um `CorralStatus` agregado a partir da lista de animais.
    private func makeCorralStatus(from animais: [Animal]) -> CorralStatus {
        let total = animais.count
        let consumoDiario = animais.reduce(0) { $0 + $1.consumoDiario }
        let receita = animais.reduce(0) { $0 + $1.lucroEstimado }

        let alertas = animais
            .filter { $0.lucroEstimado < 0 }
            .map { animal in
                AlertPayload(
                    id: "lucro-\(animal.id)",
                    type: "default",
                    title: "Lucro negativo",
                    subtitle: "\(animal.nome) está com prejuízo estimado",
                    time: "Hoje"
                )
            }

        return CorralStatus(
            totalAnimals: total,
            animalsInCorral: total,
            monitoredOnline: total,
            feedScheduled: total,
            feedConsumptionKg: consumoDiario,
            feedGoalKg: consumoDiario,
            monthlyRevenue: receita,
            alerts: alertas,
            recentActivities: [],
            zones: [],
            lastUpdated: Date()
        )
    }

    private func mapToDashboard(_ status: CorralStatus) -> DashboardData {
        let feedPct = status.feedGoalKg > 0
            ? status.feedConsumptionKg / status.feedGoalKg
            : 0

        return DashboardData(
            userName: dashboard.userName,
            location: dashboard.location,
            temperature: dashboard.temperature,
            weatherDescription: dashboard.weatherDescription,
            overview: [
                OverviewMetric(icon: "pawprint.fill", iconColor: "green",
                               value: "\(status.totalAnimals)", label: "Total", subtitle: "Rebanho cadastrado"),
                OverviewMetric(icon: "scalemass.fill", iconColor: "yellow",
                               value: String(format: "%.0f kg", averageWeight()), label: "Peso médio",
                               subtitle: "Por animal"),
                OverviewMetric(icon: "leaf.fill", iconColor: "blue",
                               value: String(format: "%.0f kg", status.feedConsumptionKg), label: "Consumo diário",
                               subtitle: "Total do rebanho"),
                OverviewMetric(icon: "dollarsign.circle.fill", iconColor: "purple",
                               value: formatCurrency(totalMarketValue()), label: "Valor de mercado",
                               subtitle: "Rebanho total")
            ],
            indicators: [
                DailyIndicator(title: "Consumo de ração",
                               value: String(format: "%.0f kg", status.feedConsumptionKg),
                               progress: feedPct, progressLabel: String(format: "%.0f%% da meta diária", feedPct * 100),
                               trend: nil, trendUp: nil),
                DailyIndicator(title: "Lucro estimado",
                               value: formatCurrency(status.monthlyRevenue),
                               progress: nil, progressLabel: nil,
                               trend: status.monthlyRevenue >= 0 ? "Resultado positivo" : "Resultado negativo",
                               trendUp: status.monthlyRevenue >= 0)
            ],
            alerts: status.alerts.map {
                AlertItem(icon: alertIcon(for: $0.type), iconColor: alertColor(for: $0.type),
                          title: $0.title, subtitle: $0.subtitle, time: $0.time)
            },
            activities: status.recentActivities.map {
                ActivityItem(icon: "arrow.right.circle.fill", description: $0.description, time: $0.time)
            }
        )
    }

    // MARK: - Métricas derivadas (expostas às telas)

    func averageWeight() -> Double {
        guard !animais.isEmpty else { return 0 }
        return animais.reduce(0) { $0 + $1.pesoAtual } / Double(animais.count)
    }

    func totalMarketValue() -> Double {
        animais.reduce(0) { $0 + $1.valorMercado }
    }

    /// Custo mensal de alimentação do rebanho (custo diário × 30).
    func monthlyFeedingCost() -> Double {
        animais.reduce(0) { $0 + $1.custoAlimentacao } * 30
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func alertIcon(for type: String) -> String {
        switch type {
        case "vaccine": return "syringe.fill"
        case "feeding": return "bowl.fill"
        case "out_of_bounds": return "exclamationmark.triangle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private func alertColor(for type: String) -> String {
        switch type {
        case "vaccine": return "pink"
        case "feeding": return "yellow"
        case "out_of_bounds": return "red"
        default: return "red"
        }
    }
}
