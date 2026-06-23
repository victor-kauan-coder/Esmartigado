import SwiftUI

/// Tela 5.1 do guia — calibração do recipiente de ração.
struct RacaoConfigView: View {
    @EnvironmentObject var iotService: IoTService
    @Environment(\.dismiss) private var dismiss

    @State private var distanciaVazio = 40.0
    @State private var distanciaCheio = 5.0
    @State private var capacidade = 20.0
    @State private var salvando = false
    @State private var salvo = false

    var body: some View {
        Form {
            Section {
                Text("Informe as medidas do recipiente para que o sistema calcule o percentual e o peso de ração a partir da distância lida pelo sensor.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("Calibração") {
                campo(titulo: "Distância recipiente vazio", valor: $distanciaVazio, unidade: "cm")
                campo(titulo: "Distância recipiente cheio", valor: $distanciaCheio, unidade: "cm")
                campo(titulo: "Capacidade total", valor: $capacidade, unidade: "kg")
            }

            Section {
                Button {
                    Task {
                        salvando = true
                        await iotService.salvarConfig(
                            distanciaVazioCm: distanciaVazio,
                            distanciaCheioCm: distanciaCheio,
                            capacidadeKg: capacidade
                        )
                        salvando = false
                        salvo = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        if salvando { ProgressView() } else { Text("Salvar configuração").bold() }
                        Spacer()
                    }
                }
                .disabled(salvando || !valido)
            } footer: {
                if !valido {
                    Text("A distância de \"vazio\" deve ser maior que a de \"cheio\" e a capacidade deve ser positiva.")
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
    }

    private var valido: Bool {
        distanciaVazio > distanciaCheio && capacidade > 0 && distanciaCheio >= 0
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

    private func carregar() async {
        await iotService.fetchConfig()
        if let c = iotService.configRecipiente {
            if let v = c.distanciaVazioCm { distanciaVazio = v }
            if let ch = c.distanciaCheioCm { distanciaCheio = ch }
            if let cap = c.capacidadeKg { capacidade = cap }
        }
    }
}

#Preview {
    NavigationStack {
        RacaoConfigView()
            .environmentObject(IoTService())
    }
}
