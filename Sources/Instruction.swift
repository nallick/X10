//
//  Instruction.swift
//
//  Copyright © 2016-2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    /// An X10 instruction typically consisting of an address and a command.
    ///
    public struct Instruction {
        public let address: Address
        public let message: Message

        /// Returns the X10 messages required to perform the receiver.
        ///
        public var messages: [X10.Message] {
            if self.message.requiresAddress { return [self.address.message, self.message] }
            return [self.message]
        }

        /// Initialize an instruction from an address and a message.
        ///
        /// - Parameter address: The X10 address of the instruction.
        /// - Parameter message: The X10 message of the instruction.
        ///
        public init(address: Address, message: Message) {
            self.address = address
            self.message = message
        }

        /// Initialize an instruction from an address and a command.
        /// - Parameter address: The X10 address of the instruction.
        /// - Parameter command: The X10 command of the instruction.
        ///
        public init(address: Address, command: CommandCode) {
            self.address = address
            self.message = Message(house: address.house, command: command)
        }
    }

    /// An X10 command code.
    ///
    public enum CommandCode: UInt8, CaseIterable {

        case allUnitsOff =    0x00
        case allLightsOn =    0x01
        case on =             0x02
        case off =            0x03
        case dim =            0x04
        case bright =         0x05
        case allLightsOff =   0x06
        case extendedCode =   0x07
        case hailReq =        0x08
        case hailAck =        0x09
        case presetDim1 =     0x0A
        case presetDim2 =     0x0B
        case extendedData =   0x0C
        case statusOn =       0x0D
        case statusOff =      0x0E
        case statusReq =      0x0F

        /// Specifies if the receiver normally affects the devices in an entire house code, or a single device.
        ///
        public var isHouseCommand: Bool {
            return self == .allUnitsOff || self == .allLightsOn || self == .allLightsOff
        }

        /// Returns a description of the receiver as a string.
        ///
        public var description: String {
            return "\(self)".titleCased()
        }

        /// Returns a command code with a specified name.
        ///
        /// - Parameter name: The notation describing the command code.
        ///
        /// - Returns: The house code matching the name (if any).
        ///
        public static func named(_ name: String) -> CommandCode? {
            return self.allCases.first{ "\($0)" == name }
        }
    }
}

extension X10.Instruction: CustomStringConvertible {

    /// Returns a description of the receiver as a string.
    ///
    public var description: String {
        return (self.address.device > 0) ? "\(self.address).\(self.message.description)" : "\(self.address.house).\(self.message.description)"
    }
}

extension X10.Instruction {

    public enum QueueStrategy {
        case append, drop, replace
    }

    /// Specifies the strategy to use when placing the receiver in an pending execution queue following another pending instruction.
    ///
    /// - Parameter previous: The previous instruction in the queue.
    ///
    /// - Returns: The strategy to use for the receiver in the queue.
    ///
    public func queueStrategy(after previous: X10.Instruction) -> QueueStrategy {
        if previous.address == self.address {
            let previousSetsLevel = previous.message.setsLevelDirectly
            if previousSetsLevel && self.message.setsLevelDirectly { return .replace}
            if previousSetsLevel && self.message.power == true { return .drop}
        }

        return .append
    }
}
