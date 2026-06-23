import Foundation

/// Cliente REST para os endpoints de animais expostos pelo Node-RED.
///
/// Esta é a API utilizada pelo projeto da branch `feature/dashboard`
/// (CRUD em `http://127.0.0.1:1880/animais`).
final class AnimaisAPI {
    let baseURL: String

    init(baseURL: String = IoTConfig.animaisURLString) {
        self.baseURL = baseURL
    }

    func listar() async throws -> [Animal] {
        let url = URL(string: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        // Decode tolerante: animais malformados são ignorados em vez de
        // fazer a lista inteira falhar.
        let wrapped = try JSONDecoder().decode([FailableDecodable<Animal>].self, from: data)
        return wrapped.compactMap(\.value)
    }

    func criar(animal: [String: Any]) async throws {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [animal])
        _ = try await URLSession.shared.data(for: request)
    }

    func atualizar(animal: Animal) async throws {
        let url = URL(string: "\(baseURL)/\(animal.id)")!
        var request = URLRequest(url: url)
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
        let url = URL(string: "\(baseURL)/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }
}
