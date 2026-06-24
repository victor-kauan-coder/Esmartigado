import SwiftUI

/// Tela 5.3 do guia — gestão dos horários de medição automática.
struct AlarmesView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var novoHorario = Date()
    @State private var processando = false
    @State private var mostrarErro = false

    var body: some View {
        List {
            Section("Novo horário") {
                HStack {
                    DatePicker("", selection: $novoHorario, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Button {
                        adicionar()
                    } label: {
                        Label("Adicionar", systemImage: "plus.circle.fill")
                    }
                    // Em uma linha de List com DatePicker, é necessário um
                    // buttonStyle explícito para o toque chegar ao botão.
                    .buttonStyle(.borderless)
                    .disabled(processando)
                }
            }

            Section("Horários cadastrados") {
                if iotService.alarmes.isEmpty {
                    Text("Nenhum horário cadastrado")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(iotService.alarmes, id: \.self) { hora in
                        HStack {
                            Image(systemName: "alarm.fill")
                                .foregroundStyle(AppTheme.accentBlue)
                            Text(hora)
                                .font(.body.monospacedDigit())
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        let horarios = indexSet.map { iotService.alarmes[$0] }
                        Task {
                            for h in horarios {
                                await iotService.removerAlarme(hora: h)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Alarmes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await iotService.fetchAlarmes() }
        .alert("Não foi possível adicionar", isPresented: $mostrarErro) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(iotService.lastError ?? "Verifique a conexão com o Node-RED e tente novamente.")
        }
    }

    private func adicionar() {
        Task {
            processando = true
            let ok = await iotService.adicionarAlarme(hora: horaString(novoHorario))
            processando = false
            if !ok { mostrarErro = true }
        }
    }

    private func horaString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        AlarmesView()
            .environmentObject(IoTService())
    }
}
