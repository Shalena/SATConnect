# SATConnect

SATConnect is a SwiftUI iOS app for discovering and interacting with Bluetooth Low Energy (BLE) peripherals. It scans for nearby devices, lets you open devices whose names contain `SAT`, and exposes the services and characteristics reported by the connected peripheral.

## Features

- Scan for nearby BLE peripherals.
- Display each discovered device's name and identifier.
- Connect to and disconnect from a selected `SAT` device.
- Discover the device's services and characteristics.
- Read characteristic values.
- Write UTF-8 strings with or without a response.
- Subscribe to notification and indication characteristics.
- Display the latest characteristic values and up to 50 incoming device messages.
- Show discovery, read, write, and subscription errors in the UI.

## Requirements

- macOS with Xcode installed.
- An iOS target with SwiftUI and CoreBluetooth support.
- A physical iPhone and a compatible BLE peripheral for meaningful testing.

The repository currently contains the Swift source files and asset catalogs, but does not include an `.xcodeproj`, `.xcworkspace`, `Package.swift`, or `Info.plist`. There is therefore no checked-in Xcode project that can be opened and built directly from this checkout.

## Setup and run

1. In Xcode, create or open an iOS SwiftUI application target named `SATConnect`.
2. Add the repository's Swift files to the target, preserving these groups:
   - `SATConnectApp.swift`
   - `Classes/` — Bluetooth state and navigation coordination.
   - `Helpers/` — the discovered-device model.
   - `Views/` — the SwiftUI screens for scanning, device details, and services.
3. Add `Assets.xcassets` and `Preview Content/Preview Assets.xcassets` to the target.
4. In the target's **Info** settings, add **Privacy - Bluetooth Always Usage Description** (`NSBluetoothAlwaysUsageDescription`) with a user-facing explanation of why the app needs Bluetooth access.
5. Select a development team and a physical iPhone as the run destination.
6. Build and run from Xcode, then grant Bluetooth access when prompted.
7. Tap the scan area on the home screen. Tap a discovered device whose name contains `SAT` to open its details, then connect to inspect its services and characteristics.

## Project structure

```text
.
├── Classes/
│   ├── BlueManager.swift       # CBCentralManager and CBPeripheral delegates
│   └── Coordinator.swift       # Navigation path and shared Bluetooth manager
├── Helpers/
│   └── DiscoveredDevice.swift  # Identifiable BLE peripheral model
├── Views/
│   ├── RootView.swift          # Navigation stack
│   ├── HomeView.swift          # Scanning and discovered-device list
│   ├── DeviceDetailsScreen.swift
│   └── Services.swift           # Service, characteristic, and BLE actions UI
├── Assets.xcassets/
├── Preview Content/
└── SATConnectApp.swift         # Application entry point
```

## Configuration and BLE behavior

`BluetoothManager` creates the CoreBluetooth central manager, scans without a service UUID filter, and discovers all services and characteristics after connecting. Characteristic writes send the entered text as UTF-8 and are limited by the peripheral's maximum write length. Notification and indication subscriptions are enabled only when the characteristic supports them.

The app does not contain server endpoints, API keys, or other application credentials. BLE permissions and the connected peripheral's own services determine what can be discovered and used at runtime.

## Contributing

1. Create a branch for your change.
2. Keep changes focused and follow the existing SwiftUI/CoreBluetooth patterns.
3. Test Bluetooth flows on a physical iPhone with a compatible peripheral.
4. Include a clear description of behavior changes and any required target or permission configuration in your pull request.
