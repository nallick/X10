//
//  Message.swift
//
//  Copyright © 2016-2019, 2024 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    public enum MessageType {
        case address(Int)
        case bright(UInt8)
        case command(CommandCode)
        case dim(UInt8)
        case extended([UInt8])
        case presetDim(HouseCode, CommandCode)
    }

    /// An X10 message typically consisting of an house code and a message type.
    ///
    public struct Message {
        public let house: HouseCode
        public let type: MessageType

        /// Specifies the maximum number of times a dim or bright message can be repeated.
        ///
		public static let maximumRepeatCount: UInt8 = 22

        /// Specifies if the receiver requires an address to be sent just before it.
        ///
        public var requiresAddress: Bool {
            switch self.type {
                // technically an extended message doesn't require an address, but omitting it seems to make the CM11A unstable
//                case .extended(_): return false
                case .command(let code): return !code.isHouseCommand
                default: return true
            }
        }

        /// Specifies if the receiver can set the brightness level of a device directly, rather than with increment bright and dim commands.
        ///
        public var setsLevelDirectly: Bool {
            switch self.type {
                case .extended(_), .presetDim(_, _): return true
                default: return false
            }
        }

        /// Specifies the level, or level delta (for bright and dim messages) if any, the receiver will result in when executed.
        ///
        public var level: Int? {
            switch self.type {
                case .address, .command(_): return nil
                case .bright(let repeatCount):
                    return X10.Message.levelDeltaFromRepeatCount(Int(repeatCount))
                case .dim(let repeatCount):
                    return -X10.Message.levelDeltaFromRepeatCount(Int(repeatCount))
                case .extended(let data):
                    guard data.count == 3, data.last == X10.presetDimExtendedCommand else { return nil }
                    return X10.Message.levelFromExtendedCode(data[1])
                case .presetDim(let house, let code):
                    return X10.presetLevelFor(house: house, command: code)
            }
        }

        /// Specifies the power on/off setting if any, the receiver will result in when executed.
        ///
        public var power: Bool? {
            switch self.type {
                case .address, .bright(_), .dim(_), .presetDim(_,_):
                    return nil
                case .command(let code):
                    guard code == .on || code == .off else { return nil }
                    return code == .on
                case .extended(let data):
                    guard data.count == 3, data.last == X10.presetDimExtendedCommand else { return nil }
                    return data[1] > 0
            }
        }

        /// Initialize an address message from a house code and address.
        ///
        /// - Parameter house: The message house code.
        /// - Parameter address: The message address.
        ///
        public init(house: HouseCode, address: Int) {
            self.house = house
            self.type = .address(address)
        }

        /// Initialize a message from a house code, a command code and data bytes.
        /// - Parameter house: The message house code.
        /// - Parameter command: The message command code
        /// - Parameter data: The message data bytes.
        ///
        public init(house: HouseCode, command: CommandCode, data: [UInt8] = []) {
            self.house = house
            if data.count == 0 {
                self.type = .command(command)
            } else {
                switch command {
                    case .bright:
						let repeatCount = min(data[0], Message.maximumRepeatCount)
                        self.type = (data.count == 1) ? .bright(repeatCount) : .command(command)
                    case .dim:
						let repeatCount = min(data[0], Message.maximumRepeatCount)
                        self.type = (data.count == 1) ? .dim(repeatCount) : .command(command)
                    case .extendedCode:
                        self.type = (data.count == 3) ? .extended(data) : .command(command)
                    default:
                        self.type = .command(command)
                }
            }
        }

		/// Create a preset dim message using an extended code.
		///
		/// - Parameter house: the house code
		/// - Parameter device: the device number
		/// - Parameter level: the dim level (1 ..< 100)
		///
		public init(house: HouseCode, device: Int, level: Int) {
            let adjustedLevel = X10.Message.levelForExtendedCode(level)
			let extendedData = [house.rawValue | UInt8(X10.deviceAddr[device]), adjustedLevel, X10.presetDimExtendedCommand]
			self.init(house: house, command: .extendedCode, data: extendedData)
		}

		/// Create a preset dim message using a preset dim code.
		///
		/// - Parameter house: the house code
		/// - Parameter level: the dim level (1 ..< 100)
		///
		public init(house: HouseCode, level: Int) {
			let presetDimEntry = presetDimTable[X10.levelToPresetDimTableIndex(level)]
            self.house = house
            self.type = .presetDim(presetDimEntry.house, presetDimEntry.command)
		}

        /// Create a message to set the brightness level directly (if possible in the specified environment).
        ///
        /// - Parameter address: The device address.
        /// - Parameter level: The requested device level (0 ... 100).
        /// - Parameter environment: The current X10 device environment.
        ///
        public init?(address: Address, level: Int, environment: Environment?) {
            guard environment?.canSetLevel(at: address) == true else { return nil }

            if environment?.isExtended(at: address) == true {
                self.init(house: address.house, device: address.device, level: level)
            } else {
                self.init(house: address.house, level: level)
            }
        }

        /// Compute the change of brightness level from a series of repeated bright or dim commands.
        ///
        /// - Parameter repeatCount: The number of repeated commands.
        ///
        /// - Returns: The level change (0 ... 100).
        ///
        public static func levelDeltaFromRepeatCount(_ repeatCount: Int) -> Int {
           return Int(round(Float(repeatCount)*100.0/22.0))
        }

        /// Compute the value needed as the payload of an extended X10 command to set to a specific brightness level.
        ///
        /// - Parameter level: The brightness level (0 ... 100) desired.
        ///
        /// - Returns: The extended data payload required.
        ///
        public static func levelForExtendedCode(_ level: Int) -> UInt8 {
           return max(1, min(63, UInt8(round(Float(level)*63.0/100.0))))
        }

        /// Compute the brightness level resulting from the payload of an extended data message.
        ///
        /// - Parameter data: The X10 extended data payload.
        ///
        /// - Returns: A brightness level from 0 ... 100.
        ///
        public static func levelFromExtendedCode(_ data: UInt8) -> Int {
           return Int(round(Float(data)*100.0/63.0))
        }
    }
}

extension X10.Message: CustomStringConvertible {

    /// Returns a description of the receiver as a string.
    ///
    public var description: String {
        switch self.type {
            case .address(let device): return "\(self.house.description)\(device)"
            case .bright(let count): return "\(self.house.description)-Bright(\(count))"
            case .command(let code): return "\(self.house.description)-\(code.description)"
            case .dim(let count): return "\(self.house.description)-Dim(\(count))"
            case .extended(let data): return "\(self.house.description)-Extended \(data)"
            case .presetDim(_, _): return "\(self.house.description)-\(self.level!)"
        }
    }
}

extension X10 {

	private struct PresetDimEntry {
		let level: Int
		let fadeRate: Float
		let house: HouseCode
		let command: CommandCode
	}

    /// A table of brightness levels and fade rates associated with the X10 commands PresetDim1 and PresetDim2.
    ///
	private static let presetDimTable = [
		PresetDimEntry(level: 0, fadeRate: 9.0, house: .M, command: .presetDim1),
		PresetDimEntry(level: 3, fadeRate: 8.5, house: .N, command: .presetDim1),
		PresetDimEntry(level: 6, fadeRate: 8.5, house: .O, command: .presetDim1),
		PresetDimEntry(level: 10, fadeRate: 8.5, house: .P, command: .presetDim1),
		PresetDimEntry(level: 13, fadeRate: 6.5, house: .C, command: .presetDim1),
		PresetDimEntry(level: 16, fadeRate: 6.5, house: .D, command: .presetDim1),
		PresetDimEntry(level: 19, fadeRate: 6.5, house: .A, command: .presetDim1),
		PresetDimEntry(level: 23, fadeRate: 6.5, house: .B, command: .presetDim1),
		PresetDimEntry(level: 26, fadeRate: 4.5, house: .E, command: .presetDim1),
		PresetDimEntry(level: 29, fadeRate: 4.5, house: .F, command: .presetDim1),
		PresetDimEntry(level: 32, fadeRate: 4.5, house: .G, command: .presetDim1),
		PresetDimEntry(level: 35, fadeRate: 4.5, house: .H, command: .presetDim1),
		PresetDimEntry(level: 39, fadeRate: 2.0, house: .K, command: .presetDim1),
		PresetDimEntry(level: 42, fadeRate: 2.0, house: .L, command: .presetDim1),
		PresetDimEntry(level: 45, fadeRate: 2.0, house: .I, command: .presetDim1),
		PresetDimEntry(level: 48, fadeRate: 2.0, house: .J, command: .presetDim1),
		PresetDimEntry(level: 52, fadeRate: 0.5, house: .M, command: .presetDim2),
		PresetDimEntry(level: 55, fadeRate: 0.5, house: .N, command: .presetDim2),
		PresetDimEntry(level: 58, fadeRate: 0.5, house: .O, command: .presetDim2),
		PresetDimEntry(level: 61, fadeRate: 0.5, house: .P, command: .presetDim2),
		PresetDimEntry(level: 65, fadeRate: 0.3, house: .C, command: .presetDim2),
		PresetDimEntry(level: 68, fadeRate: 0.3, house: .D, command: .presetDim2),
		PresetDimEntry(level: 71, fadeRate: 0.3, house: .A, command: .presetDim2),
		PresetDimEntry(level: 74, fadeRate: 0.3, house: .B, command: .presetDim2),
		PresetDimEntry(level: 77, fadeRate: 0.2, house: .E, command: .presetDim2),
		PresetDimEntry(level: 81, fadeRate: 0.2, house: .F, command: .presetDim2),
		PresetDimEntry(level: 84, fadeRate: 0.2, house: .G, command: .presetDim2),
		PresetDimEntry(level: 87, fadeRate: 0.2, house: .H, command: .presetDim2),
		PresetDimEntry(level: 90, fadeRate: 0.1, house: .K, command: .presetDim2),
		PresetDimEntry(level: 94, fadeRate: 0.1, house: .L, command: .presetDim2),
		PresetDimEntry(level: 97, fadeRate: 0.1, house: .I, command: .presetDim2),
		PresetDimEntry(level: 100, fadeRate: 0.1, house: .J, command: .presetDim2)
	]

    /// Returns the index of the preset dim table entry needed to provide a specfic brightness level.
    ///
    /// - Parameter level: The desired brightness level (0 ... 100).
    ///
    /// - Returns: The index of the preset dim table entry to supply the best approximation of the desired brightness level.
    ///
	internal static func levelToPresetDimTableIndex(_ level: Int) -> Int {
		guard level > 0 else { return 0 }

		if level < 100 {
			for index in 1 ..< X10.presetDimTable.count {
				if level <= X10.presetDimTable[index].level {
					return index
				}
			}
		}

		return X10.presetDimTable.count - 1
	}

    /// Returns the brightness level from the preset dim table for a specific house code and command code combination.
    ///
    /// - Parameter house: The house code in the preset dim table.
    /// - Parameter command: The command code in the preset dim table (i.e., .presetDim1 or .presetDim2).
    ///
    /// - Returns: The brightness level (0 ... 100), or nil if a non-preset dim command is supplied.
    ///
    internal static func presetLevelFor(house: HouseCode, command: CommandCode) -> Int? {
        guard command == .presetDim1 || command == .presetDim2 else { return nil }
        let tableEntry = X10.presetDimTable.first { $0.house == house && $0.command == command }
        return tableEntry?.level
    }
}
