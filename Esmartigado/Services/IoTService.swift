import Foundation
import Combine

/// Configuração de conexão com o Node-RED
enum IoTConfig {
    /// URL base do Node-RED (ajuste para IP da sua rede local)
    static let baseURL = "http://127.0.0.1:1880/"
    static let apiPath = "/api/esmartigado"
    static let wsPath = "/ws/esmartigado"

    static var dashboardURL: URL {
        URL(string: "\(baseURL)\(apiPath)/dashboard")!
    }

    static var statusURL: URL {
        URL(string: "\(baseURL)\(apiPath)/status")!
    }

    static var sensorsURL: URL {
        URL(string: "\(baseURL)\(apiPath)/sensors")!
    }

    static var wsURL: URL {
        URL(string: "ws://192.168.1.100:1880\(wsPath)")!
    }
}

@MainActor
final class IoTService: ObservableObject {
    @Published var corralStatus: CorralStatus?
    @Published var dashboard: DashboardData = .preview
    @Published var isConnected = false
    @Published var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var pollingTimer: Timer?
    private var hasStarted = false
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startPolling()
        connectWebSocket()
    }

    deinit {
        pollingTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - REST API (Node-RED HTTP endpoints)

    func fetchDashboard() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: IoTConfig.dashboardURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isConnected = false
                return
            }
            let status = try decoder.decode(CorralStatus.self, from: data)
            corralStatus = status
            dashboard = mapToDashboard(status)
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
        }
    }

    func fetchSensors() async -> [ZoneStatus] {
        do {
            let (data, _) = try await URLSession.shared.data(from: IoTConfig.sensorsURL)
            return try decoder.decode([ZoneStatus].self, from: data)
        } catch {
            return corralStatus?.zones ?? []
        }
    }

    // MARK: - WebSocket (eventos em tempo real do Node-RED)

    func connectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = URLSession.shared.webSocketTask(with: IoTConfig.wsURL)
        webSocketTask?.resume()
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleWebSocketMessage(message)
                    self.receiveMessage()
                }
            case .failure:
                Task { @MainActor in
                    self.isConnected = false
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    self.connectWebSocket()
                }
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }

        if let event = try? decoder.decode(PresenceEvent.self, from: data) {
            appendActivity(from: event)
        } else if let status = try? decoder.decode(CorralStatus.self, from: data) {
            corralStatus = status
            dashboard = mapToDashboard(status)
            isConnected = true
        }
    }

    // MARK: - Polling fallback

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchDashboard()
            }
        }
        Task { await fetchDashboard() }
    }

    // MARK: - Mapping

    private func mapToDashboard(_ status: CorralStatus) -> DashboardData {
        let inCorralPct = status.totalAnimals > 0
            ? Int(Double(status.animalsInCorral) / Double(status.totalAnimals) * 100)
            : 0
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
                               value: "\(status.totalAnimals)", label: "Total", subtitle: "+ 8 este mês"),
                OverviewMetric(icon: "square.grid.2x2.fill", iconColor: "yellow",
                               value: "\(status.animalsInCorral)", label: "No curral",
                               subtitle: "\(inCorralPct)% do total"),
                OverviewMetric(icon: "leaf.fill", iconColor: "blue",
                               value: "\(status.feedScheduled)", label: "Alimentação", subtitle: "Programados"),
                OverviewMetric(icon: "location.fill", iconColor: "purple",
                               value: "\(status.monitoredOnline)", label: "Monitorados", subtitle: "Online")
            ],
            indicators: [
                DailyIndicator(title: "Consumo de ração",
                               value: String(format: "%.0f kg", status.feedConsumptionKg),
                               progress: feedPct, progressLabel: String(format: "%.0f%% da meta diária", feedPct * 100),
                               trend: nil, trendUp: nil),
                DailyIndicator(title: "Receita do mês",
                               value: formatCurrency(status.monthlyRevenue),
                               progress: nil, progressLabel: nil,
                               trend: "↑ 12% em relação ao mês anterior", trendUp: true)
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

    private func appendActivity(from event: PresenceEvent) {
        let desc: String
        switch event.eventType {
        case .entered:
            desc = "Animal \(event.animalTag ?? event.sensorId) (\(event.animalName ?? "")) entrou em \(event.zone)"
        case .exited:
            desc = "Animal \(event.animalTag ?? event.sensorId) saiu de \(event.zone)"
        case .outOfBounds:
            desc = "Animal \(event.animalTag ?? "?") fora da área permitida em \(event.zone)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let activity = ActivityItem(icon: "arrow.right.circle.fill", description: desc,
                                    time: formatter.string(from: event.timestamp))
        dashboard.activities.insert(activity, at: 0)
    }

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
        default: return "bell.fill"
        }
    }

    private func alertColor(for type: String) -> String {
        switch type {
        case "vaccine": return "pink"
        case "feeding": return "yellow"
        case "out_of_bounds": return "red"
        default: return "gray"
        }
    }
}
