//
//  Address.swift
//
//  Copyright © 2016-2019, 2024 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    /// An X10 house code and device number.
    ///
    public struct Address: Codable, Hashable {

        public enum Status: Error {
            case invalidNotation
        }

        public let house: HouseCode
        public let device: Int

        /// Specifies if the receiver is the address for an entire house, rather than a single device.
        ///
        public var isHouseAddress: Bool {
            return self.device == 0
        }

        /// Returns an X10 message describing the receiver.
        ///
        public var message: X10.Message {
            return X10.Message(house: self.house, address: self.device)
        }

        /// Initializes an address from a house code and device number.
        ///
        /// - Parameter house: The house code of the address.
        /// - Parameter device: The device number of the address.
        ///
        public init(house: HouseCode, device: Int) {
            self.house = house
            self.device = device
        }

        /// Initializes an address from string notation.
        ///
        /// - Parameter notation: The notation of an address.
        ///
        /// - Throws: Status.invalidNotation
        ///
        public init(_ notation: String) throws {
            if notation.count == 1 {
                guard let house = HouseCode.named(notation) else { throw Status.invalidNotation }
                self.init(house: house, device: 0)
            } else {
                let scanner = Scanner(string: notation)

                var device = 0
                guard let houseCode = scanner.scanUpToCharacters(from: CharacterSet.decimalDigits),
                    let house = HouseCode.named(String(houseCode)),
                    scanner.scanInt(&device), (1...16).contains(device)
                    else { throw Status.invalidNotation }

                self.init(house: house, device: device)
            }

/* macOS 10.15:
            guard let houseCodeCharacter = scanner.scanCharacter(), let house = HouseCode.named(String(houseCodeCharacter)) else { throw Status.invalidNotation }
            guard let device = scanner.scanInt(), (1...16).contains(device) else { throw Status.invalidNotation }
            self.init(house: house, device: device)
*/
        }
    }

    /// An X10 house code A - P.
    ///
    public enum HouseCode: UInt8, CaseIterable {

        case A = 0x60
        case B = 0xE0
        case C = 0x20
        case D = 0xA0
        case E = 0x10
        case F = 0x90
        case G = 0x50
        case H = 0xD0
        case I = 0x70
        case J = 0xF0
        case K = 0x30
        case L = 0xB0
        case M = 0x00
        case N = 0x80
        case O = 0x40
        case P = 0xC0

        /// Returns the receiver as a string.
        ///
        public var description: String {
            return "\(self)"
        }

        /// Returns the receiver as an integer in the range 0 ... 15.
        ///
        public var index: Int {
            return Int(self.rawValue >> 4)
        }

        /// Returns a house code with a specified name (i.e., "A" to "P").
        ///
        /// - Parameter name: The notation describing the house code.
        ///
        /// - Returns: The house code matching the name (if any).
        ///
        public static func named(_ name: String) -> HouseCode? {
            return self.allCases.first{ "\($0)" == name }
        }
    }

    /// A table translating the bit value of a device code to a value in the range 1 ... 16.
    /// For example, bit value 0x00 represent device code 13.
    ///
    public static let deviceCode = [13,5,3,11,15,7,1,9,14,6,4,12,16,8,2,10]        // instr 0 = device 13, instr 1 = device 5, etc. (i.e., instruction -> device)


    /// A table translating the integer value of a device code in the range 1 ... 16 into a bit value.
    /// For example device code 1 is represented by the bit value 0x06 (i.e., binary 0110).
    ///
    public static let deviceAddr = [-1,0x6,0xE,0x2,0xA,0x1,0x9,0x5,0xD,0x7,0xF,0x3,0xB,0x0,0x8,0x4,0xC]        // device -> instruction
}

extension X10.Address: RawRepresentable {

    public typealias RawValue = String

    /// An address can be represented by a string containing a letter between "A" and "P".
    ///
    public var rawValue: String {
        return self.description
    }

    /// Initialize an address with a string between "A" and "P".
    ///
    /// - Parameter rawValue: The string containing the address notation.
    ///
    public init?(rawValue: String) {
        try? self.init(rawValue)
    }
}

extension X10.Address: CustomStringConvertible {

    /// An address can be represented by a string containing a letter between "A" and "P".
    ///
    public var description: String {
        return "\(self.house.description)\(self.device)"
    }
}
