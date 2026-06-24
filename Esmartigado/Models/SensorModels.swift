import Foundation

/// Leitura bruta de um sensor de distância/presença (HC-SR04, PIR, etc.)
struct SensorReading: Codable, Identifiable {
    let id: String
    let sensorId: String
    let zone: String
    let distanceCm: Double?
    let present: Bool
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id, sensorId, zone, distanceCm, present, timestamp
    }
}

/// Evento de presença processado pelo Node-RED (entrada/saída do curral)
struct PresenceEvent: Codable, Identifiable {
    let id: String
    let animalTag: String?
    let animalName: String?
    let zone: String
    let eventType: EventType
    let sensorId: String
    let timestamp: Date

    enum EventType: String, Codable {
        case entered = "entered"
        case exited = "exited"
        case outOfBounds = "out_of_bounds"
    }
}

/// Estado agregado do curral enviado pelo Node-RED
struct CorralStatus: Codable {
    var totalAnimals: Int
    var animalsInCorral: Int
    var monitoredOnline: Int
    var feedScheduled: Int
    var feedConsumptionKg: Double
    var feedGoalKg: Double
    var monthlyRevenue: Double
    var alerts: [AlertPayload]
    var recentActivities: [ActivityPayload]
    var zones: [ZoneStatus]
    var lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case totalAnimals, animalsInCorral, monitoredOnline, feedScheduled
        case feedConsumptionKg, feedGoalKg, monthlyRevenue
        case alerts, recentActivities, zones, lastUpdated
    }
}

struct AlertPayload: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let subtitle: String
    let time: String
}

struct ActivityPayload: Codable, Identifiable {
    let id: String
    let description: String
    let time: String
}

import Foundation
import CoreLocation // Necessário para usar o CLLocationCoordinate2D

struct ZoneStatus: Identifiable, Codable {
    let id: String
    let name: String
    let sensorId: String
    let present: Bool
    let distanceCm: Double?
    let animalCount: Int
    
    // 1. Variáveis que a API envia (o Codable entende Double perfeitamente)
    var latitude: Double?
    var longitude: Double?
    
    // 2. Propriedade computada exigida pelo MapKit para desenhar os pinos
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude ?? 0.0,
            longitude: longitude ?? 0.0
        )
    }
}

/// Payload MQTT publicado pelos sensores ESP32/Arduino
struct MQTTSensorPayload: Codable {
    let deviceId: String
    let zone: String
    let distance: Double
    let present: Bool
    let timestamp: String
}
