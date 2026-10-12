//
//  RootView.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 06.10.2026.
//

import SwiftUI

enum Route: Hashable {
    case deviceDetails(DiscoveredDevice)
}

struct RootView: View {
    @StateObject var coordinator = Coordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(coordinator: coordinator, bluetoothManager: coordinator.bluetoothManager)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .deviceDetails(let device):
                        DeviceDetailsScreen(bluetoothManager: coordinator.bluetoothManager, device: device)
                    }
                }
        }
    }
}
