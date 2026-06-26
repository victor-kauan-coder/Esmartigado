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
    let bloqueado: Bool?
    let motivoBloqueio: String?

    enum CodingKeys: String, CodingKey {
        case distanciaCm = "distancia_cm"
        case percentualRacao = "percentual_racao"
        case pesoKg = "peso_kg"
        case motivoBloqueio = "motivo_bloqueio"
        case timestamp, hora, alerta, bloqueado
    }

    /// Nível de alerta da leitura (o Node-RED envia NORMAL / BAIXO / CRITICO).
    enum Nivel { case normal, baixo, critico }

    /// Medição indisponível porque o sensor de presença detectou gado no local.
    /// O Node-RED zera distância/percentual/peso e envia `alerta: "BLOQUEADO"`.
    var isBloqueado: Bool {
        if bloqueado == true { return true }
        return alerta?.uppercased().contains("BLOQUEADO") == true
    }

    /// Texto explicando o motivo do bloqueio (com fallback).
    var motivoBloqueioTexto: String {
        if let m = motivoBloqueio, !m.isEmpty { return m }
        return "Gado detectado próximo ao recipiente. Medição de ração indisponível."
    }

    var nivel: Nivel {
        if let a = alerta?.uppercased() {
            if a.contains("CRITICO") || a.contains("CRÍTICO") { return .critico }
            if a.contains("BAIXO") { return .baixo }
            if a.contains("NORMAL") { return .normal }
        }
        if let p = percentualRacao {
            if p <= 15 { return .critico }
            if p <= 30 { return .baixo }
            return .normal
        }
        if let d = distanciaCm, d > 30 { return .critico }
        return .normal
    }

    var isCritico: Bool { nivel == .critico }
    var isBaixo: Bool { nivel == .baixo }

    /// Ainda não há nenhuma medição válida.
    var semLeitura: Bool { distanciaCm == nil }

    /// Sensor fora de alcance (a placa reporta `distancia_cm: 0`).
    var foraDeAlcance: Bool { distanciaCm == 0 }

    /// Recipiente ainda não calibrado (percentual indisponível).
    var semConfiguracao: Bool { percentualRacao == nil }
}

/// Formato geométrico do recipiente (modo avançado).
enum FormatoRecipiente: String, CaseIterable, Identifiable, Codable {
    case retangular, cilindrico, funil

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .retangular: return "Retangular"
        case .cilindrico: return "Cilíndrico"
        case .funil: return "Funil"
        }
    }
}

/// Calibração do recipiente de ração.
struct ConfigRecipiente: Codable {
    var distanciaVazioCm: Double?
    var distanciaCheioCm: Double?
    var capacidadeKg: Double?

    // Modo avançado (opcional — o usuário escolhe preencher ou não)
    var modoAvancado: Bool?
    var formato: FormatoRecipiente?
    var comprimentoCm: Double?
    var larguraCm: Double?
    var alturaCm: Double?
    var diametroCm: Double?
    var diametroSuperiorCm: Double?
    var diametroInferiorCm: Double?
    /// Densidade aparente da ração em kg/L.
    var densidadeKgL: Double?

    enum CodingKeys: String, CodingKey {
        case distanciaVazioCm = "distancia_vazio_cm"
        case distanciaCheioCm = "distancia_cheio_cm"
        case capacidadeKg = "capacidade_kg"
        case modoAvancado = "modo_avancado"
        case formato
        case comprimentoCm = "comprimento_cm"
        case larguraCm = "largura_cm"
        case alturaCm = "altura_cm"
        case diametroCm = "diametro_cm"
        case diametroSuperiorCm = "diametro_superior_cm"
        case diametroInferiorCm = "diametro_inferior_cm"
        case densidadeKgL = "densidade_kg_l"
    }

    var configurado: Bool {
        guard let v = distanciaVazioCm, let c = distanciaCheioCm, let cap = capacidadeKg else { return false }
        return v > c && cap > 0
    }

    var usaModoAvancado: Bool { modoAvancado == true }

    /// Volume interno total em litros (cm³ → L), a partir das dimensões do modo avançado.
    func volumeLitros() -> Double? {
        guard usaModoAvancado, let formato, let h = alturaCm, h > 0 else { return nil }

        let volumeCm3: Double?
        switch formato {
        case .retangular:
            guard let l = comprimentoCm, let w = larguraCm, l > 0, w > 0 else { return nil }
            volumeCm3 = l * w * h
        case .cilindrico:
            guard let d = diametroCm, d > 0 else { return nil }
            let r = d / 2
            volumeCm3 = .pi * r * r * h
        case .funil:
            guard let dSup = diametroSuperiorCm, let dInf = diametroInferiorCm,
                  dSup > 0, dInf > 0 else { return nil }
            let R = dSup / 2
            let r = dInf / 2
            // Tronco de cone: V = (π·h/3)·(R² + R·r + r²)
            volumeCm3 = (.pi * h / 3) * (R * R + R * r + r * r)
        }

        guard let volumeCm3 else { return nil }
        return (volumeCm3 / 1000 * 100).rounded() / 100
    }

    /// Capacidade em kg = volume (L) × densidade (kg/L).
    func capacidadeCalculadaKg() -> Double? {
        guard let litros = volumeLitros(),
              let densidade = densidadeKgL, densidade > 0 else { return nil }
        return (litros * densidade * 100).rounded() / 100
    }

    /// Volume atual em litros, a partir do percentual de preenchimento (modo avançado).
    func volumeAtualLitros(percentual: Double?) -> Double? {
        guard let maxLitros = volumeLitros(),
              let pct = percentual, pct >= 0 else { return nil }
        return (maxLitros * pct / 100 * 100).rounded() / 100
    }

    /// Campos do modo avançado preenchidos de forma consistente.
    var modoAvancadoValido: Bool {
        guard usaModoAvancado, let formato, let h = alturaCm, h > 0,
              let densidade = densidadeKgL, densidade > 0 else { return false }
        switch formato {
        case .retangular:
            guard let l = comprimentoCm, let w = larguraCm, l > 0, w > 0 else { return false }
        case .cilindrico:
            guard let d = diametroCm, d > 0 else { return false }
        case .funil:
            guard let dSup = diametroSuperiorCm, let dInf = diametroInferiorCm,
                  dSup > 0, dInf > 0 else { return false }
        }
        return capacidadeCalculadaKg() != nil
    }

    /// Payload para `POST /config-recipiente` (campos simples + avançados opcionais).
    func payloadAPI(capacidadeFinalKg: Double) -> [String: Any] {
        var body: [String: Any] = [
            "distancia_vazio_cm": distanciaVazioCm ?? 0,
            "distancia_cheio_cm": distanciaCheioCm ?? 0,
            "capacidade_kg": capacidadeFinalKg
        ]
        if let modoAvancado { body["modo_avancado"] = modoAvancado }
        if let formato { body["formato"] = formato.rawValue }
        if let comprimentoCm { body["comprimento_cm"] = comprimentoCm }
        if let larguraCm { body["largura_cm"] = larguraCm }
        if let alturaCm { body["altura_cm"] = alturaCm }
        if let diametroCm { body["diametro_cm"] = diametroCm }
        if let diametroSuperiorCm { body["diametro_superior_cm"] = diametroSuperiorCm }
        if let diametroInferiorCm { body["diametro_inferior_cm"] = diametroInferiorCm }
        if let densidadeKgL { body["densidade_kg_l"] = densidadeKgL }
        if let vol = volumeLitros() { body["volume_litros"] = vol }
        return body
    }
}

/// Período aceito por `GET /consumo`.
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

    /// Quantos dias o gráfico reserva no eixo X (com ou sem consumo).
    var diasNoGrafico: Int {
        switch self {
        case .dia, .semana: return 7
        case .mes: return 30
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

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Data convertida (a partir de "YYYY-MM-DD"), para uso em eixo temporal.
    var dataDate: Date? { Self.isoFormatter.date(from: data) }

    /// Rótulo curto "dd/MM" para exibição.
    var label: String {
        guard let d = dataDate else { return data }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f.string(from: d)
    }
}

/// Resposta de `GET /consumo`: total no período + série diária.
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

        // O flow oficial retorna `consumo_por_dia` como objeto { "YYYY-MM-DD": kg }.
        // Mantém suporte a array { data, consumo } por robustez.
        let key = AnyKey("consumo_por_dia")
        if let dict = try? c.decode([String: Double].self, forKey: key) {
            consumoPorDia = dict
                .map { ConsumoDia(data: $0.key, consumo: $0.value) }
                .sorted { $0.data < $1.data }
        } else if let arr = try? c.decode([ConsumoDia].self, forKey: key) {
            consumoPorDia = arr
        } else {
            consumoPorDia = []
        }
    }

    /// Intervalo fixo do eixo X para o gráfico não esticar uma única barra.
    func intervaloGrafico(periodo: PeriodoConsumo, referencia: Date = Date()) -> ClosedRange<Date> {
        let cal = Calendar.current
        let ultimo = cal.startOfDay(for: referencia)
        let primeiro = cal.date(byAdding: .day, value: -(periodo.diasNoGrafico - 1), to: ultimo) ?? ultimo
        let fim = cal.date(byAdding: .day, value: 1, to: ultimo) ?? ultimo
        return primeiro...fim
    }

    /// Dias com consumo > 0 e data válida (para desenhar barras sem esticar o eixo).
    func barrasParaGrafico() -> [ConsumoDia] {
        consumoPorDia.filter { ($0.dataDate != nil) && $0.consumo > 0 }
    }
}

/// Previsão de consumo de ração calculada no app a partir da série diária,
/// combinando **regressão linear** (tendência) com **sazonalidade semanal**
/// (fator por dia da semana).
struct PrevisaoConsumo {
    /// Média de consumo por dia (kg).
    let mediaDiariaKg: Double
    /// Quantos dias entraram no cálculo.
    let diasConsiderados: Int
    /// Inclinação da regressão (kg/dia): positiva = consumo subindo.
    let tendenciaKgPorDia: Double
    /// Quanto já foi consumido na semana atual (kg).
    let consumidoSemanaAtualKg: Double
    /// Estimativa total para a semana atual (consumido + projeção dos dias restantes).
    let previsaoSemanaAtualKg: Double
    /// Estimativa para a próxima semana (soma da projeção diária).
    let previsaoProximaSemanaKg: Double
    /// Projeção dia a dia da próxima semana (para gráfico).
    let previsaoProximosDias: [ConsumoDia]

    enum Tendencia { case crescente, estavel, decrescente }

    var temDados: Bool { diasConsiderados > 0 }

    var tendencia: Tendencia {
        let limite = max(0.05, mediaDiariaKg * 0.05)
        if tendenciaKgPorDia > limite { return .crescente }
        if tendenciaKgPorDia < -limite { return .decrescente }
        return .estavel
    }

    static func calcular(de dias: [ConsumoDia],
                         referencia now: Date = Date(),
                         calendar: Calendar = .current) -> PrevisaoConsumo {
        let hoje = calendar.startOfDay(for: now)

        let isoFmt = DateFormatter()
        isoFmt.locale = Locale(identifier: "en_US_POSIX")
        isoFmt.dateFormat = "yyyy-MM-dd"

        let pontos: [(data: Date, kg: Double)] = dias.compactMap {
            guard let d = $0.dataDate else { return nil }
            return (calendar.startOfDay(for: d), $0.consumo)
        }.sorted { $0.data < $1.data }

        guard let base0 = pontos.first?.data else {
            return PrevisaoConsumo(mediaDiariaKg: 0, diasConsiderados: 0, tendenciaKgPorDia: 0,
                                   consumidoSemanaAtualKg: 0, previsaoSemanaAtualKg: 0,
                                   previsaoProximaSemanaKg: 0, previsaoProximosDias: [])
        }

        func indiceDia(_ d: Date) -> Double {
            Double(calendar.dateComponents([.day], from: base0, to: d).day ?? 0)
        }

        // Usa apenas dias completos (anteriores a hoje) para ajustar o modelo.
        let completos = pontos.filter { $0.data < hoje }
        let ajuste = completos.isEmpty ? pontos : completos
        let n = Double(ajuste.count)
        let media = ajuste.isEmpty ? 0 : ajuste.reduce(0) { $0 + $1.kg } / n

        // --- Regressão linear (mínimos quadrados) ---
        var slope = 0.0
        var intercept = media
        if ajuste.count >= 2 {
            let xs = ajuste.map { indiceDia($0.data) }
            let ys = ajuste.map { $0.kg }
            let mediaX = xs.reduce(0, +) / n
            let mediaY = ys.reduce(0, +) / n
            var num = 0.0, den = 0.0
            for i in 0..<ajuste.count {
                num += (xs[i] - mediaX) * (ys[i] - mediaY)
                den += (xs[i] - mediaX) * (xs[i] - mediaX)
            }
            if den != 0 {
                slope = num / den
                intercept = mediaY - slope * mediaX
            }
        }

        // --- Sazonalidade semanal (fator por dia da semana) ---
        var fatorSemana: [Int: Double] = [:]
        if media > 0 {
            var soma: [Int: Double] = [:]
            var cont: [Int: Int] = [:]
            for p in ajuste {
                let w = calendar.component(.weekday, from: p.data)
                soma[w, default: 0] += p.kg
                cont[w, default: 0] += 1
            }
            for (w, c) in cont where c > 0 {
                let mediaW = soma[w]! / Double(c)
                fatorSemana[w] = min(1.5, max(0.5, mediaW / media)) // limita exageros
            }
        }

        func prever(_ d: Date) -> Double {
            var v = intercept + slope * indiceDia(d)
            if v < 0 { v = 0 }
            let w = calendar.component(.weekday, from: d)
            if let f = fatorSemana[w] { v *= f }
            return max(0, (v * 100).rounded() / 100)
        }

        // --- Semana atual e próxima ---
        var consumidoSemana = 0.0
        var previstoRestante = 0.0
        var proximaSemana = 0.0
        var proximosDias: [ConsumoDia] = []

        if let semana = calendar.dateInterval(of: .weekOfYear, for: now) {
            let inicio = calendar.startOfDay(for: semana.start)
            let fimExcl = calendar.startOfDay(for: semana.end)

            consumidoSemana = pontos
                .filter { $0.data >= inicio && $0.data <= hoje }
                .reduce(0) { $0 + $1.kg }

            var d = calendar.date(byAdding: .day, value: 1, to: hoje) ?? fimExcl
            while d < fimExcl {
                previstoRestante += prever(d)
                d = calendar.date(byAdding: .day, value: 1, to: d) ?? fimExcl.addingTimeInterval(1)
            }

            var nd = fimExcl
            for _ in 0..<7 {
                let v = prever(nd)
                proximaSemana += v
                proximosDias.append(ConsumoDia(data: isoFmt.string(from: nd), consumo: v))
                nd = calendar.date(byAdding: .day, value: 1, to: nd) ?? nd.addingTimeInterval(86_400)
            }
        }

        return PrevisaoConsumo(
            mediaDiariaKg: media,
            diasConsiderados: ajuste.count,
            tendenciaKgPorDia: slope,
            consumidoSemanaAtualKg: consumidoSemana,
            previsaoSemanaAtualKg: consumidoSemana + previstoRestante,
            previsaoProximaSemanaKg: proximaSemana,
            previsaoProximosDias: proximosDias
        )
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
