import Foundation

/// Cliente REST para os endpoints de animais expostos pelo Node-RED (flow oficial).
///
/// Rotas: `GET /getanimais`, `POST /postanimais`, `PUT /animais/{id}`,
/// `DELETE /animais/{id}`.
final class AnimaisAPI {
    let baseURL: String

    init(baseURL: String = IoTConfig.baseURL) {
        self.baseURL = baseURL
    }

    private var listarURL: URL { URL(string: "\(baseURL)/getanimais")! }
    private var criarURL: URL { URL(string: "\(baseURL)/postanimais")! }
    private func itemURL(_ id: Int) -> URL { URL(string: "\(baseURL)/animais/\(id)")! }

    func listar() async throws -> [Animal] {
        let (data, _) = try await URLSession.shared.data(from: listarURL)
        // Decode tolerante: animais malformados são ignorados em vez de
        // fazer a lista inteira falhar.
        let wrapped = try JSONDecoder().decode([FailableDecodable<Animal>].self, from: data)
        return wrapped.compactMap(\.value)
    }

    func criar(animal: [String: Any]) async throws {
        var request = URLRequest(url: criarURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [animal])
        _ = try await URLSession.shared.data(for: request)
    }

    func atualizar(animal: Animal) async throws {
        var request = URLRequest(url: itemURL(animal.id))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "nome": animal.nome,
            "raca": animal.raca,
            "idade": animal.idade,
            "sexo": animal.sexo,
            "pesoAtual": animal.pesoAtual,
            "consumoDiario": animal.consumoDiario,
            "custoAlimentacao": animal.custoAlimentacao,
            "valorMercado": animal.valorMercado
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    func deletar(id: Int) async throws {
        var request = URLRequest(url: itemURL(id))
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }
}
