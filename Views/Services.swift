//
//  Services.swift
//  SATConnect
//
//  Created by Елена Острожинская on 13.10.2026.
//

import SwiftUI
import CoreBluetooth

struct ServicesView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    private var services: [CBService] {
        bluetoothManager.servicesByPeripheralID[peripheral.identifier] ?? []
    }


    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(services, id: \.uuid) { service in
                    let characteristics =
                          bluetoothManager.characteristicsByPeripheralID[peripheral.identifier]?[service.uuid.uuidString] ?? []
                    DisclosureGroup {
                        ForEach(characteristics, id: \.uuid) { characteristic in
                            CharacteristicRow(characteristic: characteristic)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(serviceName(for: service))
                            Text(service.uuid.uuidString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text("\(service.characteristics?.count ?? 0) characteristics")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Services")
    }
}

private struct CharacteristicRow: View {
    let characteristic: CBCharacteristic

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(characteristic.uuid.uuidString)
                .font(.caption.monospaced())

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(propertyNames, id: \.self) { property in
                    Text(property)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.blue.opacity(0.35), lineWidth: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var propertyNames: [String] {
        let properties = characteristic.properties
        var names: [String] = []

        if properties.contains(.read) { names.append("Read") }
        if properties.contains(.write) { names.append("Write") }
        if properties.contains(.writeWithoutResponse) { names.append("Write without response") }
        if properties.contains(.notify) { names.append("Notify") }
        if properties.contains(.indicate) { names.append("Indicate") }

        return names.isEmpty ? ["No properties"] : names
    }
}

private func serviceName(for service: CBService) -> String {
    switch service.uuid.uuidString.uppercased() {
    case "180A": "Device Information"
    default: "Service"
    }
}
