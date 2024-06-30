//
//  PeripheralManager.swift
//  PicoSensorApp
//
//  Created by Ivan Tabashki on 30.06.24.
//

import CoreBluetooth

let EnvironmentalSensingServiceUUID = CBUUID(string: "0x181A")
let TemperatureCharacteristicUUID = CBUUID(string: "0x2A6E")
let HumidityCharacteristicUUID = CBUUID(string: "0x2A6F")
let RelayCharacteristicUUID = CBUUID(string: "E04E0525-ECBC-4E2C-AAB6-A3EC009506C6")
let RelayCount = 2 // Hardcoded since there's no way to query the hardware for this, yet

class PeripheralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    @Published var isConnected = false
    @Published var peripheralName: String?
    @Published var temperature: Float?
    @Published var humidity: Float?
    @Published var relays: [Bool] = []

    let requiredServices = [ EnvironmentalSensingServiceUUID ]
    let requiredCharacteristics = [
        TemperatureCharacteristicUUID,
        HumidityCharacteristicUUID,
        RelayCharacteristicUUID,
    ]
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    
    private var tempCharacteristic: CBCharacteristic?
    private var humidityCharacteristic: CBCharacteristic?
    private var relayCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func startScan() {
        if centralManager.state == .poweredOn && !isConnected {
            centralManager.scanForPeripherals(withServices: requiredServices, options: nil)
        }
    }
    
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        startScan();
    }
    
    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered: \(peripheral)")

        if !isConnected {
            centralManager.connect(peripheral)
            centralManager.stopScan()
            peripheralName = peripheral.name
            connectedPeripheral = peripheral;
        }
    }
    
    internal func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(requiredServices)
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        peripheral.services?.forEach({ service in
            peripheral.discoverCharacteristics(requiredCharacteristics, for: service)
        })
    }

    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        peripheral.services?.forEach({ service in
            service.characteristics?.forEach({ characteristic in
                switch characteristic.uuid {
                case TemperatureCharacteristicUUID:
                    tempCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                case HumidityCharacteristicUUID:
                    humidityCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                case RelayCharacteristicUUID:
                    relayCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    return
                }
            })
        })
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        temperature = readTemperature()
        humidity = readHumidity()
        relays = readRelays()
    }
    
    internal func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        isConnected = false

        connectedPeripheral = nil
        tempCharacteristic = nil
        humidityCharacteristic = nil
        relayCharacteristic = nil
        
        startScan()
    }
    
    func setRelayState(index: Int, value: Bool) {
        if let characteristic = relayCharacteristic {
            if index < relays.count {
                relays[index] = value
                let byteCount = (relays.count + 7) / 8; // Divide round-up bit trick
                var packedBits = [UInt8].init(repeating: 0, count: byteCount);
                for (bitIndex, value) in relays.enumerated() {
                    let byteIndex = bitIndex / 8;
                    packedBits[byteIndex] |= (UInt8(value ? 1 : 0) << bitIndex);
                }
                connectedPeripheral?.writeValue(Data(packedBits), for: characteristic, type: .withoutResponse)
            }
        }
    }
    
    private func dataToInt16(data: Data) -> Int16 {
        let raw = data.withUnsafeBytes({ ptr in
            return ptr.load(as: Int16.self)
        })
        return raw
    }
    
    private func readTemperature() -> Float? {
        if isConnected {
            if let characteristic = tempCharacteristic {
                if let data = characteristic.value {
                    let r = dataToInt16(data: data)
                    return Float(r) * 0.01
                }
            }
        }
        return nil
    }
    
    private func readHumidity() -> Float? {
        if let characteristic = humidityCharacteristic {
            if let data = characteristic.value {
                let r = dataToInt16(data: data)
                return Float(r) * 0.01
            }
        }
        return nil
    }
    
    private func readRelays() -> [Bool] {
        if let characteristic = relayCharacteristic {
            var bits = [Bool].init(repeating: false, count: RelayCount)
            
            // Supports an arbitrary amount of packed bits, in case RelayCount ever changes
            if let data = characteristic.value {
                for bitIndex in 0..<bits.count {
                    let byteIndex = bitIndex / 8;
                    if byteIndex < data.count {
                        let byte = data[byteIndex]
                        let mask = UInt8(1 << (bitIndex % 8));
                        bits[bitIndex] = (byte & mask) != 0;
                    }
                }
            }
            return bits
        }
        return []
    }
}
