import Foundation

/// Cliente REST para o flow de monitoramento de ração do Node-RED.
/// Consome as 8 rotas descritas no guia de integração.
final class RacaoAPI {
    let baseURL: String

    init(baseURL: String = IoTConfig.baseURL) {
        self.baseURL = baseURL
    }

    private var ultimoURL: URL { URL(string: "\(baseURL)/ultimo")! }
    private var historicoURL: URL { URL(string: "\(baseURL)/historico")! }
    private var medirURL: URL { URL(string: "\(baseURL)/medir")! }
    private var alarmeURL: URL { URL(string: "\(baseURL)/alarme")! }
    private var configURL: URL { URL(string: "\(baseURL)/config-recipiente")! }
    private var presencaURL: URL { URL(string: "\(baseURL)/presenca")! }

    private func consumoURL(periodo: PeriodoConsumo) -> URL {
        URL(string: "\(baseURL)/consumo?periodo=\(periodo.rawValue)")!
    }

    private let decoder = JSONDecoder()

    // MARK: - Leituras

    /// GET /ultimo — última leitura do sensor (distância, %, peso, alerta).
    func ultimaLeitura() async throws -> RacaoLeitura {
        let (data, _) = try await URLSession.shared.data(from: ultimoURL)
        return try decoder.decode(RacaoLeitura.self, from: data)
    }

    /// GET /historico — até 500 leituras (mais recente primeiro).
    func historico() async throws -> [RacaoLeitura] {
        let (data, _) = try await URLSession.shared.data(from: historicoURL)
        return try decoder.decode([RacaoLeitura].self, from: data)
    }

    /// GET /presenca — estado atual do sensor de presença de gado.
    func presencaGado() async throws -> PresencaGado {
        let (data, _) = try await URLSession.shared.data(from: presencaURL)
        return try decoder.decode(PresencaGado.self, from: data)
    }

    /// GET /ultimo — versão enriquecida (leitura + estado de presença).
    func ultimaLeituraComPresenca() async throws -> UltimaLeituraResponse {
        let (data, _) = try await URLSession.shared.data(from: ultimoURL)
        return try decoder.decode(UltimaLeituraResponse.self, from: data)
    }

    /// POST /medir — pede uma nova medição à placa via WebSocket.
    func medir() async throws {
        try await post(medirURL, body: [:])
    }

    // MARK: - Alarmes

    /// GET /alarme — lista os horários cadastrados (tolerante a formato).
    func listarAlarmes() async throws -> [String] {
        let (data, _) = try await URLSession.shared.data(from: alarmeURL)
        return Self.parseAlarmes(data)
    }

    /// POST /alarme — adiciona um horário de medição automática.
    func adicionarAlarme(hora: String) async throws {
        try await post(alarmeURL, body: ["hora": hora, "acao": "adicionar"])
    }

    /// POST /alarme — remove um horário existente.
    func removerAlarme(hora: String) async throws {
        try await post(alarmeURL, body: ["hora": hora, "acao": "remover"])
    }

    // MARK: - Configuração do recipiente

    /// GET /config-recipiente — calibração salva (ou `nil` se não houver).
    func obterConfig() async throws -> ConfigRecipiente? {
        let (data, _) = try await URLSession.shared.data(from: configURL)
        return try? decoder.decode(ConfigRecipiente.self, from: data)
    }

    /// POST /config-recipiente — salva a calibração do recipiente.
    func salvarConfig(_ config: ConfigRecipiente, capacidadeKg: Double) async throws {
        try await post(configURL, body: config.payloadAPI(capacidadeFinalKg: capacidadeKg))
    }

    // MARK: - Consumo

    /// GET /consumo?periodo=… — total e série diária de consumo.
    func consumo(periodo: PeriodoConsumo) async throws -> ConsumoResponse {
        let (data, _) = try await URLSession.shared.data(from: consumoURL(periodo: periodo))
        return try decoder.decode(ConsumoResponse.self, from: data)
    }

    // MARK: - Helpers

    private func post(_ url: URL, body: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    /// Extrai os horários de alarme de respostas em vários formatos:
    /// `["06:00"]`, `[{"hora":"06:00"}]` ou `{"alarmes":[...]}`.
    static func parseAlarmes(_ data: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return [] }

        func extract(_ any: Any) -> [String] {
            if let arr = any as? [Any] {
                return arr.flatMap { extract($0) }
            }
            if let s = any as? String {
                return [s]
            }
            if let dict = any as? [String: Any] {
                if let h = dict["hora"] as? String { return [h] }
                if let inner = dict["horarios_alarme"] { return extract(inner) }
                if let inner = dict["alarmes"] { return extract(inner) }
                if let inner = dict["horarios"] { return extract(inner) }
            }
            return []
        }
        return extract(obj)
    }
}
