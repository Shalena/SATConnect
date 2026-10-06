import SwiftUI

class Coordinator: ObservableObject {
    @Published var path = NavigationPath()
    let bluetoothManager = BluetoothManager()

    func start() {
        bluetoothManager.selectedPeripheral = nil
    }

    func showSecondView() {
        path.append("GarminDetailsScreen")
    }

    func goBack() {
        path.removeLast()
    }
}

