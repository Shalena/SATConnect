//
//  ContentView.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 05.10.2026.
//

import SwiftUI
import CoreBluetooth

struct HomeView: View {
    @ObservedObject var coordinator: Coordinator
    @ObservedObject var bluetoothManager: BluetoothManager
    var body: some View {
        VStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Start scanning")

            List(bluetoothManager.discoveredDevices) { device in
                HStack {
                    Text(device.name ?? "Unknown Device")
                    Spacer()
                    Text(device.id.uuidString)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }.onTapGesture {
                    if let name = device.name,
                       name.localizedCaseInsensitiveContains("SAT") {
                        coordinator.showSecondView(device: device)
                    }
                }
            }
        }
        .padding()
        .onTapGesture {
            coordinator.bluetoothManager.startScan()
        }
    }
}


