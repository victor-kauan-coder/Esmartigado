import SwiftUI

struct TrackingView: View {
    @EnvironmentObject var iotService: IoTService
    @State private var zones: [ZoneStatus] = []

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

                    corralMapPlaceholder
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Rastreamento")
            .task {
                zones = await iotService.fetchSensors()
            }
        }
    }

    private var placeholderZones: some View {
        Group {
            ZoneCard(zone: ZoneStatus(id: "1", name: "Entrada Principal", sensorId: "SR04-01",
                                      present: true, distanceCm: 45, animalCount: 1))
            ZoneCard(zone: ZoneStatus(id: "2", name: "Cocho A", sensorId: "PIR-02",
                                      present: false, distanceCm: 180, animalCount: 0))
            ZoneCard(zone: ZoneStatus(id: "3", name: "Cocho B", sensorId: "SR04-03",
                                      present: true, distanceCm: 30, animalCount: 3))
        }
    }

    private var corralMapPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppTheme.primaryGreen.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack {
                    Image(systemName: "map.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.primaryGreen)
                    Text("Mapa do curral com zonas monitoradas")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
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
                Text("Sensor: \(zone.sensorId)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let dist = zone.distanceCm {
                    Text("\(Int(dist)) cm")
                        .font(.caption.bold())
                }
                Text(zone.present ? "Presente" : "Vazio")
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

#Preview {
    TrackingView()
        .environmentObject(IoTService())
}
