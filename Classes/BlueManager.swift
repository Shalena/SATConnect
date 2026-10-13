import SwiftUI
import CoreBluetooth

private struct CharacteristicIdentifier: Hashable {
    let peripheralID: UUID
    let serviceUUID: String
    let characteristicUUID: String

    init(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        peripheralID = peripheral.identifier
        serviceUUID = characteristic.service?.uuid.uuidString ?? "unknown-service"
        characteristicUUID = characteristic.uuid.uuidString
    }
}

struct BluetoothMessage: Identifiable {
    let id: UUID
    let characteristicUUID: String
    let value: String
    let receivedAt: Date

    init(characteristicUUID: String, value: String) {
        id = UUID()
        self.characteristicUUID = characteristicUUID
        self.value = value
        receivedAt = Date()
    }
}

class BluetoothManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    @Published var statusMessage = "Ожидание включения Bluetooth..."
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedPeripheralIDs = Set<UUID>()
    @Published private(set) var servicesByPeripheralID: [UUID: [CBService]] = [:]
    @Published private(set) var characteristicsByPeripheralID:
        [UUID: [String: [CBCharacteristic]]] = [:]
    @Published private(set) var discoveryErrorsByPeripheralID: [UUID: [String]] = [:]
    @Published private var characteristicValues: [CharacteristicIdentifier: String] = [:]
    @Published private var characteristicStatuses: [CharacteristicIdentifier: String] = [:]
    @Published private var deviceMessages: [UUID: [BluetoothMessage]] = [:]
    private var responseListeningPeripheralIDs = Set<UUID>()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connect(_ peripheral: CBPeripheral) {
        guard centralManager.state == .poweredOn,
              peripheral.state == .disconnected else { return }
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        guard peripheral.state == .connected else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func startScan() {
        if centralManager.state == .poweredOn {
            discoveredDevices.removeAll()
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            print("Начато сканирование")
        } else {
            print("State raw value: \(centralManager.state.rawValue)")
            print("State description: \(centralManager.state)")
            print("Bluetooth не готов к сканированию")
        }
    }

    func readValue(for characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        guard canUse(characteristic, on: peripheral, requiring: .read) else { return }
        let identifier = identifier(for: characteristic, on: peripheral)
        characteristicValues[identifier] = nil
        characteristicStatuses[identifier] = "Reading…"
        peripheral.readValue(for: characteristic)
    }

    @discardableResult
    func writeValue(
        _ value: String,
        to characteristic: CBCharacteristic,
        on peripheral: CBPeripheral,
        type: CBCharacteristicWriteType
    ) -> Bool {
        let property: CBCharacteristicProperties = type == .withResponse ? .write : .writeWithoutResponse
        guard canUse(characteristic, on: peripheral, requiring: property) else { return false }

        let data = Data(value.utf8)
        guard data.count <= peripheral.maximumWriteValueLength(for: type) else {
            characteristicStatuses[identifier(for: characteristic, on: peripheral)] =
                "Message is too long for this characteristic."
            return false
        }

        let identifier = identifier(for: characteristic, on: peripheral)
        characteristicStatuses[identifier] = type == .withResponse
            ? "Writing…"
            : "Sent without response; delivery is not confirmed."
        peripheral.writeValue(data, for: characteristic, type: type)
        return true
    }

    func setNotifications(
        enabled: Bool,
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) {
        let supportsNotifications = characteristic.properties.contains(.notify)
            || characteristic.properties.contains(.indicate)
        guard supportsNotifications,
              canUse(characteristic, on: peripheral, requiring: nil) else {
            if !supportsNotifications {
                characteristicStatuses[identifier(for: characteristic, on: peripheral)] =
                    "This characteristic does not support notifications or indications."
            }
            return
        }

        characteristicStatuses[identifier(for: characteristic, on: peripheral)] =
            enabled ? "Enabling subscription…" : "Disabling subscription…"
        peripheral.setNotifyValue(enabled, for: characteristic)
    }

    func value(for characteristic: CBCharacteristic, on peripheral: CBPeripheral) -> String? {
        characteristicValues[identifier(for: characteristic, on: peripheral)]
    }

    func status(for characteristic: CBCharacteristic, on peripheral: CBPeripheral) -> String? {
        characteristicStatuses[identifier(for: characteristic, on: peripheral)]
    }

    func incomingMessages(on peripheral: CBPeripheral) -> [BluetoothMessage] {
        deviceMessages[peripheral.identifier] ?? []
    }

    func responseCharacteristics(on peripheral: CBPeripheral) -> [CBCharacteristic] {
        (characteristicsByPeripheralID[peripheral.identifier] ?? [:])
            .values
            .flatMap { $0 }
            .filter { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
    }

    func subscribeToResponseCharacteristics(on peripheral: CBPeripheral) {
        responseListeningPeripheralIDs.insert(peripheral.identifier)
        for characteristic in responseCharacteristics(on: peripheral) where !characteristic.isNotifying {
            setNotifications(enabled: true, for: characteristic, on: peripheral)
        }
    }

    private func identifier(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) -> CharacteristicIdentifier {
        CharacteristicIdentifier(peripheral: peripheral, characteristic: characteristic)
    }

    private func canUse(
        _ characteristic: CBCharacteristic,
        on peripheral: CBPeripheral,
        requiring property: CBCharacteristicProperties?
    ) -> Bool {
        let identifier = identifier(for: characteristic, on: peripheral)
        guard peripheral.state == .connected else {
            characteristicStatuses[identifier] = "Connect to the device before using this characteristic."
            return false
        }

        guard let service = characteristic.service,
              let discoveredCharacteristic = peripheral.services?
            .first(where: { $0.uuid == service.uuid })?
            .characteristics?
            .first(where: { $0.uuid == characteristic.uuid }) else {
            characteristicStatuses[identifier] = "This characteristic is no longer available."
            return false
        }

        if let property, !discoveredCharacteristic.properties.contains(property) {
            characteristicStatuses[identifier] = "This characteristic does not support this action."
            return false
        }
        return true
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth включен — можно сканировать"
        case .poweredOff:
            statusMessage = "Bluetooth выключен — включите Bluetooth"
        case .unsupported:
            statusMessage = "Устройство не поддерживает Bluetooth"
        case .unauthorized:
            statusMessage = "Нет разрешения на использование Bluetooth"
        case .resetting:
            statusMessage = "Сброс состояния Bluetooth, подождите..."
        case .unknown:
            fallthrough
        @unknown default:
            statusMessage = "Неизвестное состояние Bluetooth"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
                self.discoveredDevices.append(DiscoveredDevice(peripheral: peripheral))
                print("Найдено устройство: \(peripheral.name ?? "Без имени")")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)  // Запрос всех сервисов
        connectedPeripheralIDs.insert(peripheral.identifier)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedPeripheralIDs.remove(peripheral.identifier)
        responseListeningPeripheralIDs.remove(peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Не удалось подключиться к устройству \(peripheral.name ?? ""): \(error?.localizedDescription ?? "нет ошибки")")
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            discoveryErrorsByPeripheralID[peripheral.identifier] = [
                "Service discovery failed: \(error.localizedDescription)"
            ]
            print("Service discovery failed: \(error.localizedDescription)")
            return
        }
        discoveryErrorsByPeripheralID[peripheral.identifier] = []
        let services = peripheral.services ?? []
        servicesByPeripheralID[peripheral.identifier] = services
        characteristicsByPeripheralID[peripheral.identifier] = [:]
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        servicesByPeripheralID[peripheral.identifier] = peripheral.services ?? []
        if let error {
            var errors = discoveryErrorsByPeripheralID[peripheral.identifier] ?? []
            errors.append(
                "Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)"
            )
            discoveryErrorsByPeripheralID[peripheral.identifier] = errors
            return
        }

        var discovered = characteristicsByPeripheralID[peripheral.identifier] ?? [:]
        discovered[service.uuid.uuidString] = service.characteristics ?? []
        characteristicsByPeripheralID[peripheral.identifier] = discovered
        if responseListeningPeripheralIDs.contains(peripheral.identifier) {
            subscribeToResponseCharacteristics(on: peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = identifier(for: characteristic, on: peripheral)
        if let error {
            characteristicStatuses[identifier] =
                "Value update failed: \(error.localizedDescription)"
            return
        }

        guard let data = characteristic.value else {
            characteristicStatuses[identifier] = "No value was returned."
            return
        }

        let value = String(data: data, encoding: .utf8) ?? data.map { String(format: "%02X", $0) }.joined()
        characteristicValues[identifier] = value
        if characteristic.isNotifying {
            var messages = deviceMessages[peripheral.identifier] ?? []
            messages.append(
                BluetoothMessage(
                    characteristicUUID: characteristic.uuid.uuidString,
                    value: value
                )
            )
            deviceMessages[peripheral.identifier] = Array(messages.suffix(50))
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let identifier = identifier(for: characteristic, on: peripheral)
        if let error {
            characteristicStatuses[identifier] = "Write failed: \(error.localizedDescription)"
        } else {
            characteristicStatuses[identifier] =
                "BLE write acknowledged by the peripheral (transport only)."
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = identifier(for: characteristic, on: peripheral)
        if let error {
            characteristicStatuses[identifier] =
                "Subscription failed: \(error.localizedDescription)"
        } else {
            characteristicStatuses[identifier] = characteristic.isNotifying
                ? "Subscribed. Waiting for device messages."
                : "Subscription disabled."
        }
    }
}
