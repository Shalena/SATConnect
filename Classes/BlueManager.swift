import SwiftUI
import CoreBluetooth

let writeCharacteristicUUID = "7F4A1002-8C9D-4B55-A1B2-123456789ABC" // write, write without response

class BluetoothManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    @Published var statusMessage = "Ожидание включения Bluetooth..."
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedPeripheralIDs = Set<UUID>()

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

    func sendPing(to peripheral: CBPeripheral) {
        let uuid = CBUUID(string: writeCharacteristicUUID)

        guard let characteristic = peripheral.services?
            .lazy
            .compactMap({ service in
                service.characteristics?.first(where: { $0.uuid == uuid })
            })
            .first else {
            print("Characteristic \(uuid) not found")
            return
        }

        guard characteristic.properties.contains(.write) else {
            print("Characteristic \(uuid) does not support writes with response")
            return
        }

        peripheral.writeValue(
            Data("PING".utf8),
            for: characteristic,
            type: .withResponse
        )
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
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Не удалось подключиться к устройству \(peripheral.name ?? ""): \(error?.localizedDescription ?? "нет ошибки")")
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }

        for characteristic in service.characteristics ?? [] {
               var properties: [String] = []
               let p = characteristic.properties

               if p.contains(.read) { properties.append("read") }
               if p.contains(.write) { properties.append("write") }
               if p.contains(.writeWithoutResponse) { properties.append("writeWithoutResponse") }
               if p.contains(.notify) { properties.append("notify") }
               if p.contains(.indicate) { properties.append("indicate") }

               print("Characteristic UUID: \(characteristic.uuid), properties: \(properties)")
           }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
            if let text = String(data: data, encoding: .utf8) {
                print("Данные с \(peripheral.name ?? "устройства"): \(text)")
            } else {
                print("Получены данные, но они не являются корректным UTF-8: \(data)")
            }
        if let err = error {
            print("Ошибка: \(err.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Ошибка подписки на уведомления для характеристики: \(error.localizedDescription)")
        } else {
            print("Подписка на уведомления для характеристики обновлена. isNotifying = \(characteristic.isNotifying)")
        }
    }
}

