//
//  DiscoveredDevice.swift
//  SATConnect
//
//  Created by Olena Ostrozhynska on 06.10.2026.
//
import CoreBluetooth

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let name: String?
    let peripheral: CBPeripheral
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.id = peripheral.identifier
        self.name = peripheral.name
    }
}
