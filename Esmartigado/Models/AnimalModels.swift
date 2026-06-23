import Foundation

/// Animal cadastrado no rebanho (origem: API /animais do Node-RED)
struct Animal: Identifiable, Codable {
    var id: Int
    var nome: String
    var raca: String
    var idade: Int
    var sexo: String
    var pesoAtual: Double
    var consumoDiario: Double
    var custoAlimentacao: Double
    var valorMercado: Double
    var lucroEstimado: Double
    var historicoPeso: [RegistroPeso]

    enum CodingKeys: String, CodingKey {
        case id, nome, raca, idade, sexo, pesoAtual, consumoDiario
        case custoAlimentacao, valorMercado, lucroEstimado, historicoPeso
    }
}

extension Animal {
    /// Decode tolerante: apenas `id` é obrigatório. Os demais campos assumem
    /// valores padrão se vierem ausentes, nulos ou com tipo inesperado, evitando
    /// que um único animal incompleto derrube a lista inteira.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nome = (try? c.decode(String.self, forKey: .nome)) ?? "Sem nome"
        raca = (try? c.decode(String.self, forKey: .raca)) ?? "—"
        idade = (try? c.decode(Int.self, forKey: .idade)) ?? 0
        sexo = (try? c.decode(String.self, forKey: .sexo)) ?? "M"
        pesoAtual = (try? c.decode(Double.self, forKey: .pesoAtual)) ?? 0
        consumoDiario = (try? c.decode(Double.self, forKey: .consumoDiario)) ?? 0
        custoAlimentacao = (try? c.decode(Double.self, forKey: .custoAlimentacao)) ?? 0
        valorMercado = (try? c.decode(Double.self, forKey: .valorMercado)) ?? 0
        lucroEstimado = (try? c.decode(Double.self, forKey: .lucroEstimado))
            ?? (valorMercado - custoAlimentacao * 30)
        historicoPeso = (try? c.decode([RegistroPeso].self, forKey: .historicoPeso)) ?? []
    }
}

/// Registro de peso no histórico de um animal
struct RegistroPeso: Codable, Identifiable {
    var id = UUID()
    var data: String
    var peso: Double

    enum CodingKeys: String, CodingKey {
        case data, peso
    }
}

/// Wrapper que permite decodificar uma coleção ignorando elementos inválidos.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}
