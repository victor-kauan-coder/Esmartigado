import Foundation

/// Leitura do sensor de nível de ração (flow "Sensor de Ração" do Node-RED).
///
/// A placa (ESP8266 + HC-SR04) só mede quando recebe `"medir"` via WebSocket e
/// devolve `{"distancia_cm": X}`. O Node-RED enriquece com percentual, peso,
/// horário e nível de alerta.
struct RacaoLeitura: Codable, Identifiable {
    var id = UUID()
    let distanciaCm: Double?
    let percentualRacao: Double?
    let pesoKg: Double?
    let timestamp: String?
    let hora: String?
    let alerta: String?

    enum CodingKeys: String, CodingKey {
        case distanciaCm = "distancia_cm"
        case percentualRacao = "percentual_racao"
        case pesoKg = "peso_kg"
        case timestamp, hora, alerta
    }

    /// `true` quando o Node-RED marcou a leitura como crítica.
    var isCritico: Bool {
        if let alerta { return alerta.uppercased().contains("CRITICO") || alerta.uppercased().contains("CRÍTICO") }
        if let p = percentualRacao { return p <= 15 }
        if let d = distanciaCm, d > 30 { return true }
        return false
    }

    /// Ainda não há nenhuma medição válida.
    var semLeitura: Bool { distanciaCm == nil }

    /// Sensor fora de alcance (a placa reporta `distancia_cm: 0`).
    var foraDeAlcance: Bool { distanciaCm == 0 }

    /// Recipiente ainda não calibrado (percentual indisponível).
    var semConfiguracao: Bool { percentualRacao == nil }
}

/// Calibração do recipiente de ração.
struct ConfigRecipiente: Codable {
    var distanciaVazioCm: Double?
    var distanciaCheioCm: Double?
    var capacidadeKg: Double?

    enum CodingKeys: String, CodingKey {
        case distanciaVazioCm = "distancia_vazio_cm"
        case distanciaCheioCm = "distancia_cheio_cm"
        case capacidadeKg = "capacidade_kg"
    }

    var configurado: Bool {
        distanciaVazioCm != nil && distanciaCheioCm != nil && capacidadeKg != nil
    }
}

/// Período aceito por `GET /api/consumo`.
enum PeriodoConsumo: String, CaseIterable, Identifiable {
    case dia, semana, mes
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .dia: return "Dia"
        case .semana: return "Semana"
        case .mes: return "Mês"
        }
    }
}

/// Consumo de ração agrupado por dia (pronto para o gráfico).
struct ConsumoDia: Identifiable, Decodable {
    var id = UUID()
    let data: String
    let consumo: Double

    init(data: String, consumo: Double) {
        self.data = data
        self.consumo = consumo
    }

    /// Decode tolerante: aceita variações de nome de campo do backend.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        data = AnyKey.firstString(in: c, keys: ["data", "dia", "date"]) ?? ""
        consumo = AnyKey.firstDouble(in: c, keys: ["consumo", "kg", "total", "valor", "consumo_kg"]) ?? 0
    }
}

/// Resposta de `GET /api/consumo`: total no período + série diária.
struct ConsumoResponse: Decodable {
    let total: Double
    let consumoPorDia: [ConsumoDia]

    init(total: Double, consumoPorDia: [ConsumoDia]) {
        self.total = total
        self.consumoPorDia = consumoPorDia
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        total = AnyKey.firstDouble(in: c, keys: [
            "total_consumido_kg", "total_kg", "total_consumido", "consumo_total", "total"
        ]) ?? 0
        consumoPorDia = (try? c.decode([ConsumoDia].self, forKey: AnyKey("consumo_por_dia")))
            ?? (try? c.decode([ConsumoDia].self, forKey: AnyKey("consumoPorDia")))
            ?? []
    }
}

/// Chave dinâmica para leitura tolerante de JSON com nomes de campo variáveis.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }

    static func firstDouble(in c: KeyedDecodingContainer<AnyKey>, keys: [String]) -> Double? {
        for k in keys {
            if let v = try? c.decode(Double.self, forKey: AnyKey(k)) { return v }
        }
        return nil
    }

    static func firstString(in c: KeyedDecodingContainer<AnyKey>, keys: [String]) -> String? {
        for k in keys {
            if let v = try? c.decode(String.self, forKey: AnyKey(k)) { return v }
        }
        return nil
    }
}
