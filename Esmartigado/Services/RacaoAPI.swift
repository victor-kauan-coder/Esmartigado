import Foundation

/// Cliente REST para o flow de monitoramento de ração do Node-RED
/// ("Sensor Completo"): leitura de nível, histórico, medição sob demanda
/// e configuração do horário de alarme.
final class RacaoAPI {
    let baseURL: String

    init(baseURL: String = IoTConfig.baseURL) {
        self.baseURL = baseURL
    }

    private var ultimoURL: URL { URL(string: "\(baseURL)/api/ultimo")! }
    private var historicoURL: URL { URL(string: "\(baseURL)/api/historico")! }
    private var medirURL: URL { URL(string: "\(baseURL)/api/medir")! }
    private var alarmeURL: URL { URL(string: "\(baseURL)/api/alarme")! }

    private let decoder = JSONDecoder()

    /// GET /api/ultimo — última leitura do sensor.
    func ultimaLeitura() async throws -> RacaoLeitura {
        let (data, _) = try await URLSession.shared.data(from: ultimoURL)
        return try decoder.decode(RacaoLeitura.self, from: data)
    }

    /// GET /api/historico — até 50 leituras (mais recente primeiro).
    func historico() async throws -> [RacaoLeitura] {
        let (data, _) = try await URLSession.shared.data(from: historicoURL)
        return try decoder.decode([RacaoLeitura].self, from: data)
    }

    /// POST /api/medir — pede uma nova medição à placa via WebSocket.
    func medir() async throws {
        var request = URLRequest(url: medirURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        _ = try await URLSession.shared.data(for: request)
    }

    /// POST /api/alarme — define o horário diário de medição automática.
    func definirAlarme(hora: String) async throws {
        var request = URLRequest(url: alarmeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["hora": hora])
        _ = try await URLSession.shared.data(for: request)
    }
}
