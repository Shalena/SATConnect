//
//  RootView.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 06.10.2026.
//

import SwiftUI

struct RootView: View {
    @StateObject var coordinator = Coordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(coordinator: coordinator, bluetoothManager: coordinator.bluetoothManager)
                .navigationDestination(for: String.self) { route in
                    switch route {
                    case "GarminDetailsScreen":
                        GarminDetailsScreen(coordinator: coordinator)
                    default:
                        EmptyView()
                    }
                }
        }
        .onAppear {
            coordinator.start()
        }
    }
}
