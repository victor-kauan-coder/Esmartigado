import SwiftUI
import MapKit

struct TrackingView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var zones: [ZoneStatus] = []
    
    // Controle da câmera do mapa
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 1. Agora guardamos o objeto ZoneStatus inteiro para ler os dados no pop-up
    @State private var selectedZone: ZoneStatus?

    private var allMapPoints: [ZoneStatus] {
        let baseZones = zones.isEmpty ? currentPlaceholderZones : zones
        return baseZones + extraMapPins
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sensores de presença")
                        .font(.headline)

                    if zones.isEmpty {
                        placeholderZones
                    } else {
                        ForEach(zones) { zone in
                            ZoneCard(zone: zone)
                        }
                    }

                    Text("Mapa do curral")
                        .font(.headline)
                        .padding(.top)

                    corralMap
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Rastreamento")
            .task {
                // zones = await iotService.fetchSensors()
            }
            // 2. Pop-up dinâmico que reage à seleção de um ponto do mapa
            .alert(
                selectedZone?.sensorId.contains("GADO") == true ? "Informações do Animal" : "Status do Sensor",
                isPresented: .init(
                    get: { selectedZone != nil },
                    set: { if !$0 { selectedZone = nil } }
                )
            ) {
                Button("Fechar", role: .cancel) {}
            } message: {
                if let zone = selectedZone {
                    if zone.sensorId.contains("GADO") {
                        // Mensagem customizada para os Gados
                        Text("Identificação: \(zone.name)\n" +
                             "Código da Tag: \(zone.sensorId)\n" +
                             "Status: Monitorado Ativo\n" +
                             "Localização: Setor Campestre MS")
                    } else {
                        // Mensagem detalhada para as Entradas e Cochos
                        Text("Ponto: \(zone.name)\n" +
                             "ID do Hardware: \(zone.sensorId)\n" +
                             "Status Atual: \(zone.present ? "Ocupado / Detectado" : "Livre / Vazio")\n" +
                             (zone.distanceCm != nil ? "Distância da Cerca: \(Int(zone.distanceCm!)) cm\n" : "") +
                             "Contagem Local: \(zone.animalCount) gado(s)")
                    }
                }
            }
        }
    }
    
    struct ZoneCard: View {
        let zone: ZoneStatus

        var body: some View {
            HStack {
                Circle()
                    .fill(zone.present ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .font(.subheadline.bold())
                    Text("ID: \(zone.sensorId)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let dist = zone.distanceCm {
                        Text("\(Int(dist)) cm")
                            .font(.caption.bold())
                    }
                    Text(zone.present ? "Detectado" : "Livre")
                        .font(.caption)
                        .foregroundStyle(zone.present ? .green : AppTheme.textSecondary)
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    // ESTRUTURAS FIXAS (Portões de Entrada e Cochos)
    private var currentPlaceholderZones: [ZoneStatus] {
        [
            ZoneStatus(id: "1", name: "Entrada Principal", sensorId: "SR04-01", present: true, distanceCm: 45, animalCount: 1, latitude: -19.6212, longitude: -54.8015),
            ZoneStatus(id: "2", name: "Entrada Secundária", sensorId: "SR04-02", present: false, distanceCm: nil, animalCount: 0, latitude: -19.6225, longitude: -54.8028),
            ZoneStatus(id: "3", name: "Cocho Principal", sensorId: "PIR-01", present: true, distanceCm: 25, animalCount: 4, latitude: -19.6218, longitude: -54.8020)
        ]
    }

    private var placeholderZones: some View {
        Group {
            ForEach(currentPlaceholderZones) { zone in
                ZoneCard(zone: zone)
            }
        }
    }
    
    // TAGS DOS GADOS (Animais espalhados)
    private var extraMapPins: [ZoneStatus] {
        [
            ZoneStatus(id: "gado_04", name: "Nelore Brinco 104", sensorId: "GADO-104", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6214, longitude: -54.8011),
            ZoneStatus(id: "gado_22", name: "Nelore Brinco 122", sensorId: "GADO-122", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6216, longitude: -54.8025),
            ZoneStatus(id: "gado_57", name: "Nelore Brinco 157", sensorId: "GADO-157", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6221, longitude: -54.8019),
            ZoneStatus(id: "gado_89", name: "Nelore Brinco 189", sensorId: "GADO-189", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6223, longitude: -54.8032),
            ZoneStatus(id: "gado_03", name: "Matriz 003", sensorId: "GADO-003", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6210, longitude: -54.8022),
            ZoneStatus(id: "gado_11", name: "Touro 011", sensorId: "GADO-011", present: true, distanceCm: nil, animalCount: 1, latitude: -19.6219, longitude: -54.8014)
        ]
    }

    private var corralMap: some View {
        Map(position: $cameraPosition) {
            ForEach(allMapPoints) { zone in
                Annotation(zone.name, coordinate: zone.coordinate) {
                    Button {
                        mapPinAction(for: zone)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(zone.sensorId.contains("GADO") ? Color.orange : (zone.present ? Color.green : Color.gray.opacity(0.7)))
                                .frame(width: 34, height: 34)
                                .shadow(radius: 4)
                            
                            Image(systemName: zone.sensorId.contains("GADO") ? "dot.radiowaves.up.forward" : "sensor.tag.radiowaves.forward")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .frame(height: 350)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    // 3. Atualiza o estado com o objeto completo
    private func mapPinAction(for zone: ZoneStatus) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        selectedZone = zone
    }
}
