import SwiftUI

private enum ModoConfigRecipiente: String, CaseIterable, Identifiable {
    case simples, avancado
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .simples: return "Simples"
        case .avancado: return "Avançado"
        }
    }
}

/// Calibração do recipiente de ração (modo simples ou avançado).
struct RacaoConfigView: View {
    @EnvironmentObject var iotService: IoTService
    @Environment(\.dismiss) private var dismiss

    @State private var modo: ModoConfigRecipiente = .simples
    @State private var distanciaVazio = 40.0
    @State private var distanciaCheio = 5.0
    @State private var capacidade = 20.0

    @State private var formato: FormatoRecipiente = .retangular
    @State private var comprimento = 60.0
    @State private var largura = 40.0
    @State private var altura = 30.0
    @State private var diametro = 40.0
    @State private var diametroSuperior = 50.0
    @State private var diametroInferior = 30.0
    @State private var densidade = 0.65

    @State private var salvando = false
    @State private var salvo = false

    var body: some View {
        Form {
            Section {
                Text(modo == .simples
                     ? "Informe a distância do sensor com o recipiente vazio e cheio, e a capacidade em kg."
                     : "Informe as dimensões internas do recipiente e a densidade da ração. A capacidade em kg é calculada automaticamente.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section {
                Picker("Modo", selection: $modo) {
                    ForEach(ModoConfigRecipiente.allCases) { m in
                        Text(m.titulo).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Sensor (calibração)") {
                campo(titulo: "Distância recipiente vazio", valor: $distanciaVazio, unidade: "cm")
                campo(titulo: "Distância recipiente cheio", valor: $distanciaCheio, unidade: "cm")
            }

            if modo == .simples {
                Section("Capacidade") {
                    campo(titulo: "Capacidade total", valor: $capacidade, unidade: "kg")
                }
            } else {
                Section("Formato e dimensões") {
                    Picker("Formato", selection: $formato) {
                        ForEach(FormatoRecipiente.allCases) { f in
                            Text(f.titulo).tag(f)
                        }
                    }

                    campo(titulo: "Altura interna", valor: $altura, unidade: "cm")

                    switch formato {
                    case .retangular:
                        campo(titulo: "Comprimento interno", valor: $comprimento, unidade: "cm")
                        campo(titulo: "Largura interna", valor: $largura, unidade: "cm")
                    case .cilindrico:
                        campo(titulo: "Diâmetro interno", valor: $diametro, unidade: "cm")
                    case .funil:
                        campo(titulo: "Diâmetro superior", valor: $diametroSuperior, unidade: "cm")
                        campo(titulo: "Diâmetro inferior", valor: $diametroInferior, unidade: "cm")
                    }
                }

                Section("Ração") {
                    campo(titulo: "Densidade aparente", valor: $densidade, unidade: "kg/L")
                }

                if let preview = previewAvancado {
                    Section("Capacidade calculada") {
                        LabeledContent("Volume") {
                            Text(String(format: "%.1f L", preview.litros))
                        }
                        LabeledContent("Peso máximo") {
                            Text(String(format: "%.1f kg", preview.kg))
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.primaryGreen)
                        }
                    }
                }
            }

            Section {
                Button { salvar() } label: {
                    HStack {
                        Spacer()
                        if salvando { ProgressView() } else { Text("Salvar configuração").bold() }
                        Spacer()
                    }
                }
                .disabled(salvando || !valido)
            } footer: {
                if !valido {
                    Text(mensagemErro)
                        .foregroundStyle(AppTheme.alertRed)
                } else if salvo {
                    Text("Configuração salva.")
                        .foregroundStyle(AppTheme.primaryGreen)
                }
            }
        }
        .navigationTitle("Recipiente")
        .navigationBarTitleDisplayMode(.inline)
        .task { await carregar() }
        .onChange(of: modo) { _, _ in salvo = false }
    }

    private var rascunho: ConfigRecipiente { montarConfig() }

    private var previewAvancado: (litros: Double, kg: Double)? {
        guard modo == .avancado,
              let litros = rascunho.volumeLitros(),
              let kg = rascunho.capacidadeCalculadaKg() else { return nil }
        return (litros, kg)
    }

    private var valido: Bool {
        let sensorOk = distanciaVazio > distanciaCheio && distanciaCheio >= 0
        if modo == .simples {
            return sensorOk && capacidade > 0
        }
        return sensorOk && rascunho.modoAvancadoValido
    }

    private var mensagemErro: String {
        if distanciaVazio <= distanciaCheio {
            return "A distância de \"vazio\" deve ser maior que a de \"cheio\"."
        }
        if modo == .simples && capacidade <= 0 {
            return "A capacidade deve ser positiva."
        }
        if modo == .avancado {
            return "Preencha todas as dimensões do formato escolhido e uma densidade positiva."
        }
        return ""
    }

    private func campo(titulo: String, valor: Binding<Double>, unidade: String) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            TextField(unidade, value: valor, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unidade)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func montarConfig() -> ConfigRecipiente {
        ConfigRecipiente(
            distanciaVazioCm: distanciaVazio,
            distanciaCheioCm: distanciaCheio,
            capacidadeKg: modo == .simples ? capacidade : previewAvancado?.kg,
            modoAvancado: modo == .avancado,
            formato: modo == .avancado ? formato : nil,
            comprimentoCm: modo == .avancado && formato == .retangular ? comprimento : nil,
            larguraCm: modo == .avancado && formato == .retangular ? largura : nil,
            alturaCm: modo == .avancado ? altura : nil,
            diametroCm: modo == .avancado && formato == .cilindrico ? diametro : nil,
            diametroSuperiorCm: modo == .avancado && formato == .funil ? diametroSuperior : nil,
            diametroInferiorCm: modo == .avancado && formato == .funil ? diametroInferior : nil,
            densidadeKgL: modo == .avancado ? densidade : nil
        )
    }

    private func salvar() {
        Task {
            salvando = true
            let config = montarConfig()
            await iotService.salvarConfig(config)
            salvando = false
            salvo = true
        }
    }

    private func carregar() async {
        await iotService.fetchConfig()
        guard let c = iotService.configRecipiente else { return }

        if let v = c.distanciaVazioCm { distanciaVazio = v }
        if let ch = c.distanciaCheioCm { distanciaCheio = ch }
        if let cap = c.capacidadeKg { capacidade = cap }

        if c.usaModoAvancado {
            modo = .avancado
            if let f = c.formato { formato = f }
            if let v = c.comprimentoCm { comprimento = v }
            if let v = c.larguraCm { largura = v }
            if let v = c.alturaCm { altura = v }
            if let v = c.diametroCm { diametro = v }
            if let v = c.diametroSuperiorCm { diametroSuperior = v }
            if let v = c.diametroInferiorCm { diametroInferior = v }
            if let v = c.densidadeKgL { densidade = v }
        }
    }
}

#Preview {
    NavigationStack {
        RacaoConfigView()
            .environmentObject(IoTService())
    }
}
