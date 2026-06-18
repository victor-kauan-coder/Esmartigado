import SwiftUI
import Charts

// MARK: - Model

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
}

struct RegistroPeso: Codable, Identifiable {
    var id = UUID()
    var data: String
    var peso: Double

    enum CodingKeys: String, CodingKey {
        case data, peso
    }
}

// MARK: - API Service

class AnimaisAPI {
    let baseURL = "http://127.0.0.1:1880/animais"

    func listar() async throws -> [Animal] {
        let url = URL(string: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Animal].self, from: data)
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

// MARK: - ViewModel

@Observable
@MainActor
class AnimaisViewModel {
    var animais: [Animal] = []
    var errorMessage: String?

    private let api = AnimaisAPI()

    func carregar() async {
        do {
            animais = try await api.listar()
        } catch {
            errorMessage = "Erro ao carregar: \(error.localizedDescription)"
        }
    }

    func criar(nome: String, raca: String, idade: Int, sexo: String,
               pesoAtual: Double, consumoDiario: Double,
               custoAlimentacao: Double, valorMercado: Double) async {
        let body: [String: Any] = [
            "nome": nome, "raca": raca, "idade": idade, "sexo": sexo,
            "pesoAtual": pesoAtual, "consumoDiario": consumoDiario,
            "custoAlimentacao": custoAlimentacao, "valorMercado": valorMercado
        ]
        do {
            try await api.criar(animal: body)
            await carregar()
        } catch {
            errorMessage = "Erro ao criar: \(error.localizedDescription)"
        }
    }

    func atualizar(animal: Animal) async {
        do {
            try await api.atualizar(animal: animal)
            await carregar()
        } catch {
            errorMessage = "Erro ao atualizar: \(error.localizedDescription)"
        }
    }

    func deletar(id: Int) async {
        do {
            try await api.deletar(id: id)
            await carregar()
        } catch {
            errorMessage = "Erro ao deletar: \(error.localizedDescription)"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var vm = AnimaisViewModel()
    @State private var showingNovo = false

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.animais) { animal in
                    NavigationLink(destination: DetalheAnimalView(animal: animal, vm: vm)) {
                        HStack(spacing: 12) {
                            Text("🐄")
                                .font(.system(size: 36))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(animal.nome)
                                    .font(.headline)
                                Text("\(animal.raca) · \(animal.sexo == "M" ? "Macho" : "Fêmea")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Peso: \(String(format: "%.1f", animal.pesoAtual)) kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("R$ \(String(format: "%.0f", animal.lucroEstimado))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(animal.lucroEstimado >= 0 ? .green : .red)
                                Text("lucro est.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let animal = vm.animais[index]
                        Task { await vm.deletar(id: animal.id) }
                    }
                }
            }
            .navigationTitle("🐄 GadoManager")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNovo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNovo) {
                NovoAnimalView(vm: vm)
            }
            .task {
                await vm.carregar()
            }
            .refreshable {
                await vm.carregar()
            }
        }
    }
}

// MARK: - Detalhe Animal View

struct DetalheAnimalView: View {
    @State var animal: Animal
    var vm: AnimaisViewModel
    @State private var showingEditar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Header
                VStack(spacing: 4) {
                    Text("🐄")
                        .font(.system(size: 60))
                    Text(animal.nome)
                        .font(.title.bold())
                    Text("\(animal.raca) · \(animal.idade) meses · \(animal.sexo == "M" ? "Macho" : "Fêmea")")
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Cards de stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(titulo: "Peso Atual", valor: "\(String(format: "%.1f", animal.pesoAtual)) kg", icone: "scalemass", cor: .blue)
                    StatCard(titulo: "Consumo Diário", valor: "\(String(format: "%.1f", animal.consumoDiario)) kg", icone: "leaf", cor: .green)
                    StatCard(titulo: "Custo Mensal", valor: "R$ \(String(format: "%.2f", animal.custoAlimentacao * 30))", icone: "dollarsign", cor: .orange)
                    StatCard(titulo: "Valor de Mercado", valor: "R$ \(String(format: "%.0f", animal.valorMercado))", icone: "chart.line.uptrend.xyaxis", cor: .purple)
                }
                .padding(.horizontal)

                // Lucro estimado
                VStack(spacing: 4) {
                    Text("Lucro Estimado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("R$ \(String(format: "%.2f", animal.lucroEstimado))")
                        .font(.title.bold())
                        .foregroundStyle(animal.lucroEstimado >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Histórico de peso
                if !animal.historicoPeso.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Histórico de Peso")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(animal.historicoPeso) { registro in
                                LineMark(
                                    x: .value("Data", registro.data),
                                    y: .value("Peso", registro.peso)
                                )
                                .foregroundStyle(.blue)
                                PointMark(
                                    x: .value("Data", registro.data),
                                    y: .value("Peso", registro.peso)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(animal.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Editar") {
                    showingEditar = true
                }
            }
        }
        .sheet(isPresented: $showingEditar) {
            EditarAnimalView(animal: $animal, vm: vm)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let titulo: String
    let valor: String
    let icone: String
    let cor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icone)
                .font(.title2)
                .foregroundStyle(cor)
            Text(valor)
                .font(.headline)
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Novo Animal View

struct NovoAnimalView: View {
    @Environment(\.dismiss) var dismiss
    var vm: AnimaisViewModel

    @State private var nome = ""
    @State private var raca = ""
    @State private var idade = 12
    @State private var sexo = "M"
    @State private var pesoAtual = 300.0
    @State private var consumoDiario = 10.0
    @State private var custoAlimentacao = 8.0
    @State private var valorMercado = 4000.0

    var body: some View {
        NavigationView {
            Form {
                Section("Identificação") {
                    TextField("Nome do animal", text: $nome)
                    TextField("Raça", text: $raca)
                    Stepper("Idade: \(idade) meses", value: $idade, in: 1...120)
                    Picker("Sexo", selection: $sexo) {
                        Text("Macho").tag("M")
                        Text("Fêmea").tag("F")
                    }
                }

                Section("Peso e Consumo") {
                    HStack {
                        Text("Peso atual (kg)")
                        Spacer()
                        TextField("kg", value: $pesoAtual, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Consumo diário (kg)")
                        Spacer()
                        TextField("kg", value: $consumoDiario, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Financeiro") {
                    HStack {
                        Text("Custo alimentação/dia (R$)")
                        Spacer()
                        TextField("R$", value: $custoAlimentacao, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Valor de mercado (R$)")
                        Spacer()
                        TextField("R$", value: $valorMercado, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Novo Animal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Criar") {
                        Task {
                            await vm.criar(
                                nome: nome, raca: raca, idade: idade, sexo: sexo,
                                pesoAtual: pesoAtual, consumoDiario: consumoDiario,
                                custoAlimentacao: custoAlimentacao, valorMercado: valorMercado
                            )
                            dismiss()
                        }
                    }
                    .disabled(nome.isEmpty || raca.isEmpty)
                }
            }
        }
    }
}

// MARK: - Editar Animal View

struct EditarAnimalView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var animal: Animal
    var vm: AnimaisViewModel

    var body: some View {
        NavigationView {
            Form {
                Section("Identificação") {
                    TextField("Nome", text: $animal.nome)
                    TextField("Raça", text: $animal.raca)
                    Stepper("Idade: \(animal.idade) meses", value: $animal.idade, in: 1...120)
                    Picker("Sexo", selection: $animal.sexo) {
                        Text("Macho").tag("M")
                        Text("Fêmea").tag("F")
                    }
                }

                Section("Peso e Consumo") {
                    HStack {
                        Text("Peso atual (kg)")
                        Spacer()
                        TextField("kg", value: $animal.pesoAtual, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Consumo diário (kg)")
                        Spacer()
                        TextField("kg", value: $animal.consumoDiario, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Financeiro") {
                    HStack {
                        Text("Custo alimentação/dia (R$)")
                        Spacer()
                        TextField("R$", value: $animal.custoAlimentacao, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Valor de mercado (R$)")
                        Spacer()
                        TextField("R$", value: $animal.valorMercado, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Editar Animal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salvar") {
                        Task {
                            await vm.atualizar(animal: animal)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
