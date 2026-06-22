import SwiftUI

@main
struct EsmartigadoApp: App {
    @StateObject private var iotService = IoTService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(iotService)
        }
    }
}
