//
//  X10.swift
//
//  Copyright © 2016-2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

/// X10 home automation formatting and state management.
///
public class X10 {

	public static let shared = X10()

    public static let messageIsAddressFlag: UInt8 = 0x00
    public static let messageIsCommandFlag: UInt8 = 0x80
    public static let presetDimExtendedCommand: UInt8 = 0x31

    public static let stateChangeNotification = NSNotification.Name(rawValue: "X10.StateChange")
    public static let stateChangeAddressKey = "address"
    public static let stateChangeLevelKey = "level"
    public static let stateChangePowerKey = "power"
    public static let stateChangeSourceKey = "source"
    public static let stateChangeStateKey = "state"

    public static let triggerNotification = NSNotification.Name(rawValue: "X10.Trigger")
    public static let triggerKey = "trigger"

    public static var defaultSerialOutputTimeout: TimeInterval = 20.0

    public var interface: X10Interface?

    public private(set) var environment = Environment()

    private var deviceState: [Address: State] = [:]
    private var selectedDevices = [HouseCode.Selection](repeating: HouseCode.Selection(), count: HouseCode.allCases.count)
    private var selectedScene: Address?

    /// Load an environment describing the X10 devices and scenes to be found locally.
    ///
    /// - Parameter url: The location of the environment file, or nil for the default location in the user's home directory.
    ///
    /// - Throws: Any JSON decoding or file read error encountered.
    ///
    public func loadEnvironment(from url: URL? = nil) throws {
        self.environment = try Environment.load(from: url)
    }

    /// Update the internal X10 state resulting from a series of previous messages without changing the current X10 selection.
    ///
    /// - Parameter messages: The messages describing the new state.
    /// - Parameter source: The source of the messages (e.g., an interface or broker). Can be used by notifications clients to filter changes.
    ///
    public func updateInternalState(for messages: [Message], source: String) {
        self.updateState(for: messages, manageSelection: false, source: source)
    }

    /// Update the internal X10 state resulting from a series of current messages and change the current X10 selection.
    ///
    /// - Parameter messages: The messages describing the new state.
    /// - Parameter source: The source of the messages (e.g., an interface or broker). Can be used by notifications clients to filter changes.
    ///
    public func receiveMessagesFromInterface(_ messages: [Message], source: String) {
        self.updateState(for: messages, manageSelection: true, source: source)
    }

    /// Broadcast an X10 instruction through the current  interface and update the internal state.
    ///
    /// - Parameter instruction: The instruction to broadcast.
    /// - Parameter source: The source of the messages (e.g., an interface or broker). Can be used by notifications clients to filter changes.
    /// - Parameter completion: The closure called after completion (if any).
    ///
    public func sendInstruction(_ instruction: Instruction, source: String, completion: X10Interface.Completion? = nil) {
        guard let interface = self.interface else { completion?(.connectionNotOpen); return }
        interface.send(instruction: instruction) { status in
            if status == .success {
                self.updateState(for: instruction.messages, manageSelection: true, source: source)
            }
            completion?(status)
        }
    }

    /// Returns the devices currently selected for a house code.
    ///
    /// - Parameter house: The house code.
    ///
    /// - Returns: The devices selected.
    ///
    private func selectedDevices(in house: HouseCode) -> Set<Int> {
        return self.selectedDevices[house.index].selection
	}

    /// Update the selection state to include a device.
    ///
    /// - Parameter address: The device address.
    ///
    private func selectDevice(_ address: Address) {
        self.selectedDevices[address.house.index].select(address.device)
        self.selectedScene = address
	}

    /// Update the internal X10 state resulting from a series of messages and optionally change the current X10 selection.
    ///
    /// - Parameter messages: The messages describing the new state.
    /// - Parameter manageSelection: Specifies if the current selection should be updated to reflect these messages.
    /// - Parameter source: The source of the messages.
    ///
    private func updateState(for messages: [Message], manageSelection: Bool, source: String) {
        for message in messages {
            switch message.type {
                case .address(let device): if manageSelection { self.selectDevice(Address(house: message.house, device: device)) }
                case .bright(let count): self.commandIssued(house: message.house, command: .bright, data: [count], manageSelection: manageSelection, source: source)
                case .command(let command): self.commandIssued(house: message.house, command: command, manageSelection: manageSelection, source: source)
                case .dim(let count): self.commandIssued(house: message.house, command: .dim, data: [count], manageSelection: manageSelection, source: source)
                case .extended(let data): self.commandIssued(house: message.house, command: .extendedCode, data: data, manageSelection: manageSelection, source: source)
                case .presetDim(let house, let command): self.commandIssued(house: message.house, presetDimHouse: house, command: command, manageSelection: manageSelection, source: source)
            }
        }
    }

    /// Set the internal X10 state for a device and post a notification.
    ///
    /// - Parameter newState: The new state to set.
    /// - Parameter address: The address of the device.
    /// - Parameter source: The source of the state change.
    ///
    private func setStateAndNotify(_ newState: State, for address: Address, source: String) {
        self.deviceState.updateValue(newState, forKey: address)

        var notificationInfo: [String: Any] = [X10.stateChangeAddressKey: address, X10.stateChangeStateKey: newState, X10.stateChangePowerKey: newState.on, X10.stateChangeSourceKey: source]
        if self.environment.isDimable(at: address) == true { notificationInfo[X10.stateChangeLevelKey] = newState.level }
        NotificationCenter.default.post(name: X10.stateChangeNotification, object: nil, userInfo: notificationInfo)
    }

    /// Update the internal X10 state resulting from an X10 command and optionally change the current X10 selection.
    ///
    /// - Parameter house: The house code of the command.
    /// - Parameter presetDimHouse: The house code used as part of the preset dim command (if applicable).
    /// - Parameter command: The X10 command.
    /// - Parameter data: The extended X10 data (if any).
    /// - Parameter manageSelection: Specifies if the current selection should be updated to reflect this command.
    /// - Parameter source: The source of the state change.
    ///
    private func commandIssued(house: HouseCode, presetDimHouse: HouseCode? = nil, command: CommandCode, data: [UInt8] = [], manageSelection: Bool, source: String) {
        if manageSelection {
            self.selectedDevices[house.index].closeSelection()
        }

        switch command {
			case .allUnitsOff, .allLightsOff, .allLightsOn:
                self.setPowerStateForEntireHouse(house, command: command, manageSelection: manageSelection, source: source)

			case .on:
                self.setPowerStateForSelectedDevices(house: house, onState: true, source: source)
			case .off:
                self.setPowerStateForSelectedDevices(house: house, onState: false, source: source)

            case .bright:
                self.adjustLevelForSelectedDevices(house: house, by: Int(data.first ?? 1), source: source)
            case .dim:
                self.adjustLevelForSelectedDevices(house: house, by: -Int(data.first ?? 1), source: source)

            case .extendedCode:
                if data.last == X10.presetDimExtendedCommand {
                    let device = X10.deviceCode[Int(data[0] & 0x0F)]
                    let level = X10.Message.levelFromExtendedCode(data[1])
                    self.setExtendedDeviceLevel(address: Address(house: house, device: device), level: level, source: source)
                }

            case .presetDim1, .presetDim2:
                guard let presetDimHouse = presetDimHouse, let level = X10.presetLevelFor(house: presetDimHouse, command: command) else { break }
                self.setPresetDeviceLevelForSelectedDevices(house: house, level: level, source: source)

            default:
				break
		}
	}

    /// Update the internal X10 state resulting from an X10 whole house power command and optionally change the current X10 selection.
    ///
    /// - Parameter house: The house code of the command.
    /// - Parameter command: The X10 command.
    /// - Parameter manageSelection: Specifies if the current selection should be updated to reflect this command.
    /// - Parameter source: The source of the state change.
    ///
    private func setPowerStateForEntireHouse(_ house: HouseCode, command: CommandCode, manageSelection: Bool, source: String) {
        if manageSelection {
            self.selectedDevices[house.index].deselectAll()
        }

        let trigger = "\(house)-\(command.description)"
        let notificationInfo: [String: Any] = [X10.triggerKey: trigger, X10.stateChangeSourceKey: source]
        NotificationCenter.default.post(name: X10.triggerNotification, object: nil, userInfo: notificationInfo)

        let onState = (command == .allLightsOn)
        for (address, var state) in self.deviceState {
            if self.environment.respondsToCommand(at: address, house: house, command: command) {
                state.on = onState
                self.setStateAndNotify(state, for: address, source: source)
            }
        }
    }

    /// Update the internal X10 state of the current selection resulting from an X10 selected device power command.
    ///
    /// - Parameter house: The house code of the command.
    /// - Parameter onState: The new on/off power state.
    /// - Parameter source: The source of the state change.
    ///
    private func setPowerStateForSelectedDevices(house: HouseCode, onState: Bool, source: String) {
        for device in self.selectedDevices(in: house) {
            let address = Address(house: house, device: device)
            var state = self.deviceState[address] ?? State()
            state.on = onState
            self.setStateAndNotify(state, for: address, source: source)
        }

        if let selectedScene = self.selectedScene, selectedScene.house == house {
            self.environment.scenes[selectedScene]?.forEach { sceneMember in
                let sceneIsOn = (sceneMember.level > 0)
                let state = State(on: onState && sceneIsOn, level: sceneIsOn ? sceneMember.level : 100)
                self.setStateAndNotify(state, for: sceneMember.address, source: source)
            }
        }
    }

    /// Update the internal X10 state of the current selection resulting from an X10 selected device bright or dim command.
    ///
    /// - Parameter house: The house code of the command.
    /// - Parameter repeatCount: The number of level change commands (positive to bright; negative to dim).
    /// - Parameter source: The source of the state change.
    ///
    private func adjustLevelForSelectedDevices(house: HouseCode, by repeatCount: Int, source: String) {
        let levelDelta = X10.Message.levelDeltaFromRepeatCount(repeatCount)
        for device in self.selectedDevices(in: house) {
            let address = Address(house: house, device: device)
            if self.environment.isDimable(at: address) == true, var state = self.deviceState[address], state.on {
                state.level = max(0, min(100, state.level + levelDelta))
                self.setStateAndNotify(state, for: address, source: source)
            }
        }

        if let selectedScene = self.selectedScene, selectedScene.house == house {
            self.environment.scenes[selectedScene]?.forEach { sceneMember in
                if self.environment.isDimable(at: sceneMember.address) == true, var state = self.deviceState[sceneMember.address], state.on {
                    state.level = max(0, min(100, state.level + levelDelta))
                    self.setStateAndNotify(state, for: sceneMember.address, source: source)
                }
            }
        }
    }

    /// Update the brightness level of the internal X10 state of a single device using the X10 extended level command.
    ///
    /// - Parameter address: The address of the device.
    /// - Parameter level: The level to set from 0 ... 100.
    /// - Parameter source: The source of the state change.
    ///
    private func setExtendedDeviceLevel(address: Address, level: Int, source: String) {
        if self.environment.isExtended(at: address) == true {
            self.setStateAndNotify(State(on: true, level: level), for: address, source: source)
        }
    }

    /// Update the brightness level of the internal X10 state of a single device using the X10 preset dim level commands.
    ///
    /// - Parameter address: The address of the device.
    /// - Parameter level: The level to set from 0 ... 100.
    /// - Parameter source: The source of the state change.
    ///
    private func setPresetDeviceLevelForSelectedDevices(house: HouseCode, level: Int, source: String) {
        for device in self.selectedDevices(in: house) {
            let address = Address(house: house, device: device)
            if self.environment.isPresetDimable(at: address) == true {
                let state = State(on: true, level: level)
                self.setStateAndNotify(state, for: address, source: source)
            }
        }
    }
}
