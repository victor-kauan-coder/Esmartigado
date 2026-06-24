import Foundation

struct OverviewMetric: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: String
    let value: String
    let label: String
    let subtitle: String
}

struct DailyIndicator: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let progress: Double?
    let progressLabel: String?
    let trend: String?
    let trendUp: Bool?
}

struct AlertItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: String
    let title: String
    let subtitle: String
    let time: String
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let description: String
    let time: String
}

struct DashboardData {
    var userName: String
    var location: String
    var temperature: Int
    var weatherDescription: String
    var overview: [OverviewMetric]
    var indicators: [DailyIndicator]
    var alerts: [AlertItem]
    var activities: [ActivityItem]

    /// Estado inicial: cabeçalho com clima/local fictícios (não há API para
    /// isso), mas sem números de rebanho falsos. As seções de visão geral,
    /// indicadores e alertas ficam vazias até o primeiro fetch da API.
    static let empty = DashboardData(
        userName: "Produtor",
        location: "Uberaba, MG",
        temperature: 28,
        weatherDescription: "Ensolarado",
        overview: [],
        indicators: [],
        alerts: [],
        activities: []
    )

    static let preview = DashboardData(
        userName: "João",
        location: "Uberaba, MG",
        temperature: 28,
        weatherDescription: "Ensolarado",
        overview: [
            OverviewMetric(icon: "pawprint.fill", iconColor: "green", value: "128", label: "Total", subtitle: "+ 8 este mês"),
            OverviewMetric(icon: "square.grid.2x2.fill", iconColor: "yellow", value: "96", label: "No curral", subtitle: "75% do total"),
            OverviewMetric(icon: "leaf.fill", iconColor: "blue", value: "32", label: "Alimentação", subtitle: "Programados"),
            OverviewMetric(icon: "location.fill", iconColor: "purple", value: "128", label: "Monitorados", subtitle: "Online")
        ],
        indicators: [
            DailyIndicator(title: "Consumo de ração", value: "1.250 kg", progress: 0.85, progressLabel: "85% da meta diária", trend: nil, trendUp: nil),
            DailyIndicator(title: "Receita do mês", value: "R$ 18.750,00", progress: nil, progressLabel: nil, trend: "↑ 12% em relação ao mês anterior", trendUp: true)
        ],
        alerts: [
            AlertItem(icon: "syringe.fill", iconColor: "pink", title: "Vacina vencida", subtitle: "8 animais com vacinação atrasada", time: "Hoje"),
            AlertItem(icon: "bowl.fill", iconColor: "yellow", title: "Alimentação atrasada", subtitle: "5 animais não receberam ração no horário", time: "Hoje"),
            AlertItem(icon: "exclamationmark.triangle.fill", iconColor: "red", title: "Animal fora do limite", subtitle: "1 animal está fora da área permitida", time: "Agora")
        ],
        activities: [
            ActivityItem(icon: "arrow.right.circle.fill", description: "Animal #045 (Branco) entrou no curral", time: "08:15")
        ]
    )
}
