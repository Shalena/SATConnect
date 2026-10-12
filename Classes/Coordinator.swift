import SwiftUI

class Coordinator: ObservableObject {
    @Published var path = NavigationPath()
    let bluetoothManager = BluetoothManager()

    func showSecondView(device: DiscoveredDevice) {
        path.append(Route.deviceDetails(device))
    }

    func goBack() {
        path.removeLast()
    }
}

