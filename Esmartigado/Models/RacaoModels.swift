import Foundation

/// Leitura do sensor de nível de ração (flow "Sensor Completo" do Node-RED).
///
/// A placa publica um JSON com `distancia_cm`; o Node-RED enriquece com
/// `timestamp`, `hora` e `alerta` ("CRITICO" quando a distância passa de 30 cm,
/// indicando pouca ração no recipiente).
struct RacaoLeitura: Codable, Identifiable {
    var id = UUID()
    let distanciaCm: Double?
    let timestamp: String?
    let hora: String?
    let alerta: String?

    enum CodingKeys: String, CodingKey {
        case distanciaCm = "distancia_cm"
        case timestamp, hora, alerta
    }

    /// `true` quando o Node-RED marcou a leitura como crítica.
    var isCritico: Bool {
        if let alerta { return alerta.uppercased() == "CRITICO" }
        if let distanciaCm { return distanciaCm > 30 }
        return false
    }

    /// `true` quando ainda não há nenhuma medição válida.
    var semLeitura: Bool { distanciaCm == nil }
}
