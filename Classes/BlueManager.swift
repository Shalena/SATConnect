import SwiftUI
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    @Published var statusMessage = "Ожидание включения Bluetooth..."
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var selectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connectSelectedPeriferal() {
        if let selected = selectedPeripheral {
            centralManager.connect(selected, options: nil)
        }
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
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            print("Данные с Garmin: \(data)")
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

