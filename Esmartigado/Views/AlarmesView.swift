import SwiftUI

/// Tela 5.3 do guia — gestão dos horários de medição automática.
struct AlarmesView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var novoHorario = Date()
    @State private var processando = false

    var body: some View {
        List {
            Section("Novo horário") {
                HStack {
                    DatePicker("", selection: $novoHorario, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Button {
                        Task {
                            processando = true
                            await iotService.adicionarAlarme(hora: horaString(novoHorario))
                            processando = false
                        }
                    } label: {
                        Label("Adicionar", systemImage: "plus.circle.fill")
                    }
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
