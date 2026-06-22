import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var iotService: IoTService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
                .tag(0)

            TrackingView()
                .tabItem {
                    Label("Rastreamento", systemImage: "location.fill")
                }
                .tag(1)

            FeedingView()
                .tabItem {
                    Label("Alimentação", systemImage: "leaf.fill")
                }
                .tag(2)

            FinancialView()
                .tabItem {
                    Label("Financeiro", systemImage: "dollarsign.circle.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primaryGreen)
        .task {
            iotService.start()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(IoTService())
}
