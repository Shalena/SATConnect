//
//  GarminDetailsScreen.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 05.10.2026.
//
import SwiftUI
import CoreBluetooth

struct GarminDetailsScreen: View {
    @ObservedObject var coordinator: Coordinator

    var body: some View {
        VStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Получить информацию с Garmin")
                .font(.title)
                .padding()
        }.onTapGesture {
            if coordinator.bluetoothManager.centralManager.state == .poweredOn {
                coordinator.bluetoothManager.connectSelectedPeriferal()
            } else {
                print("Bluetooth выключен или не готов")
            }
        }
    }
}


