import Foundation

/// Estado do sensor de presença de gado (endpoint de presença do Node-RED).
struct PresencaGado: Codable {
    /// `true` quando o sensor detectou animal próximo ao recipiente.
    let presenca: Bool
    /// Distância lida no momento em que o estado foi registrado.
    let distancia_cm: Double?
    /// ISO 8601 — quando o estado foi registrado pelo Node-RED.
    let timestamp: String?

    /// Mensagem legível para exibir na UI.
    var mensagemUI: String {
        if presenca {
            let dist = distancia_cm.map { String(format: "%.0f cm", $0) } ?? "—"
            return "🐄 Gado detectado próximo ao recipiente (\(dist)). Medição de ração indisponível."
        }
        return "Área livre — medição disponível."
    }
}

/// Resposta enriquecida do GET de última leitura (leitura + presença).
struct UltimaLeituraResponse: Codable {
    let leitura: RacaoLeitura
    let presenca_gado: PresencaGado
}
