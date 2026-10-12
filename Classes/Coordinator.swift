import SwiftUI

class Coordinator: ObservableObject {
    @Published var path = NavigationPath()
    let bluetoothManager = BluetoothManager()

    func start() {
        bluetoothManager.selectedPeripheral = nil
    }

    func showSecondView(device: DiscoveredDevice) {
        path.append(Route.deviceDetails(device))
    }

    func goBack() {
        path.removeLast()
    }
}

