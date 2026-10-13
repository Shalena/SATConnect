//
//  GarminDetailsScreen.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 05.10.2026.
//
import SwiftUI
import CoreBluetooth

struct DeviceDetailsScreen: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let device: DiscoveredDevice

    var body: some View {
        VStack (spacing: 20) {
            let isConnected = bluetoothManager.connectedPeripheralIDs.contains(device.id)
            Button {
                if isConnected {
                    bluetoothManager.disconnect(device.peripheral)
                } else {
                    bluetoothManager.connect(device.peripheral)
                }
            } label: {
                Text("\(isConnected ? "Disconnect" : "Connect") \(device.name ?? "device")")
            }
            .buttonStyle(TapAnimationStyle())

            Button {
                bluetoothManager.sendPing(to: device.peripheral)
            } label: {
                Text("Send ping")
            }
            .buttonStyle(TapAnimationStyle())
        }
    }

}

private struct TapAnimationStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}




