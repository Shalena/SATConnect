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
                ForEach(Array((bluetoothManager.discoveryErrorsByPeripheralID[peripheral.identifier] ?? []).enumerated()), id: \.offset) { _, error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(services, id: \.uuid) { service in
                    let characteristics =
                          bluetoothManager.characteristicsByPeripheralID[peripheral.identifier]?[service.uuid.uuidString] ?? []
                    DisclosureGroup {
                        ForEach(characteristics, id: \.uuid) { characteristic in
                            CharacteristicRow(
                                characteristic: characteristic,
                                bluetoothManager: bluetoothManager,
                                peripheral: peripheral
                            )
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
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    @State private var selection: CharacteristicActionSelection?

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(characteristic.uuid.uuidString)
                .font(.caption.monospaced())

            if supportedActions.isEmpty {
                Text("No supported actions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(supportedActions) { action in
                        Button {
                            selection = CharacteristicActionSelection(
                                action: action,
                                characteristic: characteristic
                            )
                        } label: {
                            Label(action.title, systemImage: action.symbol)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.blue.opacity(0.35), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .sheet(item: $selection) { selection in
            CharacteristicActionDetailView(
                action: selection.action,
                characteristic: selection.characteristic,
                bluetoothManager: bluetoothManager,
                peripheral: peripheral
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var supportedActions: [CharacteristicAction] {
        let properties = characteristic.properties
        return CharacteristicAction.allCases.filter { action in
            switch action {
            case .read: properties.contains(.read)
            case .write: properties.contains(.write)
            case .writeWithoutResponse: properties.contains(.writeWithoutResponse)
            case .notify: properties.contains(.notify)
            case .indicate: properties.contains(.indicate)
            }
        }
    }
}

private enum CharacteristicAction: String, CaseIterable, Identifiable {
    case read
    case write
    case writeWithoutResponse
    case notify
    case indicate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .read: "Read"
        case .write: "Write"
        case .writeWithoutResponse: "Write without response"
        case .notify: "Notify"
        case .indicate: "Indicate"
        }
    }

    var symbol: String {
        switch self {
        case .read: "arrow.down.to.line"
        case .write, .writeWithoutResponse: "arrow.up.to.line"
        case .notify, .indicate: "bell"
        }
    }
}

private struct CharacteristicActionSelection: Identifiable {
    let action: CharacteristicAction
    let characteristic: CBCharacteristic

    var id: String {
        "\(action.rawValue)-\(characteristic.service?.uuid.uuidString ?? "unknown-service")-\(characteristic.uuid.uuidString)"
    }
}

private struct CharacteristicActionDetailView: View {
    let action: CharacteristicAction
    let characteristic: CBCharacteristic
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    var body: some View {
        Group {
            switch action {
            case .read:
                ReadCharacteristicView(
                    characteristic: characteristic,
                    bluetoothManager: bluetoothManager,
                    peripheral: peripheral
                )
            case .write, .writeWithoutResponse:
                WriteCharacteristicView(
                    action: action,
                    characteristic: characteristic,
                    bluetoothManager: bluetoothManager,
                    peripheral: peripheral
                )
            case .notify, .indicate:
                SubscriptionCharacteristicView(
                    action: action,
                    characteristic: characteristic,
                    bluetoothManager: bluetoothManager,
                    peripheral: peripheral
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ReadCharacteristicView: View {
    let characteristic: CBCharacteristic
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Read value")
                .font(.title2.bold())
            Text(characteristic.uuid.uuidString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if let status = bluetoothManager.status(for: characteristic, on: peripheral) {
                Text(status)
                    .font(.subheadline)
            }

            Text(bluetoothManager.value(for: characteristic, on: peripheral) ?? "No value read yet.")
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Read again") {
                bluetoothManager.readValue(for: characteristic, from: peripheral)
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            bluetoothManager.readValue(for: characteristic, from: peripheral)
        }
    }
}

private struct WriteCharacteristicView: View {
    let action: CharacteristicAction
    let characteristic: CBCharacteristic
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    @State private var message = ""
    @State private var sentAt: Date?

    private var writeType: CBCharacteristicWriteType {
        action == .write ? .withResponse : .withoutResponse
    }

    var body: some View {
        let messages = bluetoothManager.incomingMessages(on: peripheral)
        let response = messages.last(where: { incoming in
            sentAt.map { $0 < incoming.receivedAt } ?? false
        })

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(action.title)
                    .font(.title2.bold())
                Text(characteristic.uuid.uuidString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                TextField("String to send", text: $message)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Button("Send string") {
                    let sendTime = Date()
                    if bluetoothManager.writeValue(
                        message,
                        to: characteristic,
                        on: peripheral,
                        type: writeType
                    ) {
                        sentAt = sendTime
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(message.isEmpty)

                if let status = bluetoothManager.status(for: characteristic, on: peripheral) {
                    Text(status)
                        .font(.subheadline)
                }

                Divider()
                Label("Device response", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)

                if let response {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Message received after send", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(response.characteristicUUID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(response.value)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                } else if sentAt != nil {
                    Label("Waiting for a device message…", systemImage: "clock")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Send a string to watch for the device's response.")
                        .foregroundStyle(.secondary)
                }

                Text("Listening characteristics")
                    .font(.headline)
                if bluetoothManager.responseCharacteristics(on: peripheral).isEmpty {
                    Text("No Notify or Indicate characteristics were discovered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bluetoothManager.responseCharacteristics(on: peripheral), id: \.uuid) { responseCharacteristic in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(responseCharacteristic.uuid.uuidString)
                                .font(.caption.monospaced())
                            Text(bluetoothManager.status(for: responseCharacteristic, on: peripheral)
                                 ?? "Subscribing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Messages are shown with their source characteristic. A message received after sending is not necessarily correlated to that write.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !messages.isEmpty {
                    Text("Incoming messages")
                        .font(.headline)
                    ForEach(messages.reversed()) { incomingMessage in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(incomingMessage.characteristicUUID)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(incomingMessage.value)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            bluetoothManager.subscribeToResponseCharacteristics(on: peripheral)
        }
    }
}

private struct SubscriptionCharacteristicView: View {
    let action: CharacteristicAction
    let characteristic: CBCharacteristic
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(action.title)
                .font(.title2.bold())
            Text(characteristic.uuid.uuidString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(action == .notify
                 ? "Listen for notifications from this characteristic."
                 : "Listen for indications from this characteristic.")

            Button(characteristic.isNotifying ? "Stop listening" : "Start listening") {
                bluetoothManager.setNotifications(
                    enabled: !characteristic.isNotifying,
                    for: characteristic,
                    on: peripheral
                )
            }
            .buttonStyle(.borderedProminent)

            if let status = bluetoothManager.status(for: characteristic, on: peripheral) {
                Text(status)
                    .font(.subheadline)
            }

            Text("Latest device message")
                .font(.headline)
            if let message = bluetoothManager.incomingMessages(on: peripheral).last(where: {
                $0.characteristicUUID == characteristic.uuid.uuidString
            }) {
                Text(message.value)
                    .textSelection(.enabled)
            } else {
                Text("No message received yet.")
            }
        }
    }
}

private func serviceName(for service: CBService) -> String {
    switch service.uuid.uuidString.uppercased() {
    case "180A": "Device Information"
    default: "Service"
    }
}
