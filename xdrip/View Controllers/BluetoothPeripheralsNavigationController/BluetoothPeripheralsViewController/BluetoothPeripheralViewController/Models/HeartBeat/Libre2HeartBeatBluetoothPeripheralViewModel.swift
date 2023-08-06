//
//  Libre2HeartBeatBluetoothPeripheralViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 05/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

class Libre2HeartBeatBluetoothPeripheralViewModel {
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?

}

// MARK: - conform to BluetoothPeripheralViewModel

extension Libre2HeartBeatBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
      // there's nothing to configure
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.Libre2HeartBeatType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        // there's no section specific for this type of transmitter, this function will not be called
        return ""
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // there's no section specific for this type of transmitter, this function will not be called, nothing to update
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // there's no section specific for this type of transmitter, so user won't click anything, this function will not be called
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        // there are no specific settings for this type of bluetooth peripheral
        // meaning this function should never be called
        return 0
        
    }
    
    func numberOfSections() -> Int {
        
        // there's just the man section, this function will not be called
        return 1
        
    }
    
}
