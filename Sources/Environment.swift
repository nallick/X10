//
//  Environment.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    /// An environment describes the X10 devices and scenes to be found locally.
    ///
    public struct Environment: Codable {
        public let devices: [Address: Device]
        public let scenes: [Address: [SceneMember]]

        /// The location of the environment file (defaults to an invisible file in the user's home directory).
        ///
        private static var environmentURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".x10.json")

        /// Initialize an environment.
        ///
        /// - Parameter devices: The devices in the environment.
        /// - Parameter scenes: The scenes in the environment.
        ///
        /// - Note: Defaults to an empty environment.
        ///
        public init(devices: [Address: Device] = [:], scenes: [Address: [SceneMember]] = [:]) {
            self.devices = devices
            self.scenes = scenes
        }

        /// Specifies if the device at a specific address responds to a specified command.
        ///
        /// - Parameter address: The address of the device to test.
        /// - Parameter house: The house code of the command.
        /// - Parameter command: The code of the command.
        ///
        /// - Returns: true if the device responds to the command; false otherwise.
        ///
        public func respondsToCommand(at address: Address, house: HouseCode, command: CommandCode) -> Bool {
            guard let device = self.devices[address] else { return false }
            switch command {
                case .allLightsOn: return device.universalAllLightsOn || (device.allLightsOn && house == address.house)
                case .allLightsOff: return device.universalAllLightsOff || (device.allLightsOff && house == address.house)
                case .allUnitsOff: return device.universalAllUnitsOff || (device.allUnitsOff && house == address.house)
                case .bright, .dim: return device.dims
                case .extendedCode: return device.extended
                case .presetDim1, .presetDim2: return device.preset
                default: return true
            }
        }

        /// Specifies if the device at a specific address responds to the AllLightsOn command.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device responds to the command; false if the device doesn't respond to the command or nil if unknown
        ///
        public func allLightsOn(at address: Address) -> Bool? {
            return self.devices[address]?.allLightsOn
        }

        /// Specifies if the device at a specific address responds to the AllLightsOff command.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device responds to the command; false if the device doesn't respond to the command or nil if unknown
        ///
        public func allLightsOff(at address: Address) -> Bool? {
            return self.devices[address]?.allLightsOff
        }

        /// Specifies if the device at a specific address responds to the AllUnitsOff command.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device responds to the command; false if the device doesn't respond to the command or nil if unknown
        ///
        public func allUnitsOff(at address: Address) -> Bool? {
            return self.devices[address]?.allUnitsOff
        }

        /// Specifies if the device at a specific address responds to a command to set the brightness level directly.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device can set the brightness level; false if the device can't set the level or nil if unknown
        ///
        public func canSetLevel(at address: Address) -> Bool? {
            let device = self.devices[address]
            return device?.extended == true || device?.preset == true
        }

        /// Specifies if the device at a specific address can be dimmed.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device responds to dim and bright commands; false if the device doesn't respond to dim and bright commands or nil if unknown
        ///
        public func isDimable(at address: Address) -> Bool? {
            return self.devices[address]?.dims
        }

        /// Specifies if the device at a specific address responds an extended command to set the brightness level directly.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device can set the extended brightness level; false if the device can't set the extended level or nil if unknown
        ///
        public func isExtended(at address: Address) -> Bool? {
            return self.devices[address]?.extended
        }

        /// Specifies if the device at a specific address responds an preset command to set the brightness level directly.
        ///
        /// - Parameter address: The address of the device to test.
        ///
        /// - Returns: true if the device can set the preset brightness level; false if the device can't set the preset level or nil if unknown
        ///
        public func isPresetDimable(at address: Address) -> Bool? {
            return self.devices[address]?.preset
        }

        /// Save the receiver in the current environment file location.
        ///
        /// - Throws: Any JSON encoding or file write error encountered.
        ///
        public func save() throws {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            try data.write(to: Environment.environmentURL)
        }

        /// Load an environment from the current environment file location.
        ///
        /// - Parameter url: The location of the environment file, or nil for the default location in the user's home directory.
        ///
        /// - Throws: Any JSON decoding or file read error encountered.
        ///
        public static func load(from url: URL?) throws -> Environment {
            let url = url ?? self.environmentURL
            self.environmentURL = url

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
                    return Environment(devices: [:], scenes: [:])
                }

                throw error
            }

            let decoder = JSONDecoder()
            return try decoder.decode(Environment.self, from: data)
        }
    }

    /// The environment description of the properties of an X10 device.
    ///
    public struct Device {
        public let allLightsOn: Bool              // responds to AllLightsOn on the device house code
        public let allLightsOff: Bool             // responds to AllLightsOff on the device house code
        public let allUnitsOff: Bool              // responds to AllUnitsOff on the device house code
        public let dims: Bool                     // responds to Dim and Bright
        public let extended: Bool                 // supports extended dim commands
        public let preset: Bool                   // supports preset dim commands
        public let universalAllLightsOn: Bool     // responds to AllLightsOn on any house code
        public let universalAllLightsOff: Bool    // responds to AllLightsOff on any house code
        public let universalAllUnitsOff: Bool     // responds to AllUnitsOff on any house code
    }

    /// The environment description of an element of an X10 scene.
    ///
    public struct SceneMember: Codable {
        public let address: Address
        public let level: Int       // 0-100%
    }
}

extension X10.Device: Codable {
    public enum CodingKeys: CodingKey {
        case allLightsOn, allLightsOff, allUnitsOff, dims, extended, preset, universalAllLightsOn, universalAllLightsOff, universalAllUnitsOff
    }

    /// Initialize an X10 device from JSON data.
    ///
    /// - Parameter decoder: The JSON decoder.
    ///
    /// - Throws: Any JSON parsing errors for a device.
    ///
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let allLightsOn = try container.decodeIfPresent(Bool.self, forKey: .allLightsOn) ?? true
        let allLightsOff = try container.decodeIfPresent(Bool.self, forKey: .allLightsOff) ?? true
        let isLight = (allLightsOn && allLightsOff)

        self.allLightsOn = allLightsOn
        self.allLightsOff = allLightsOff
        self.allUnitsOff = try container.decodeIfPresent(Bool.self, forKey: .allUnitsOff) ?? true
        self.dims = try container.decodeIfPresent(Bool.self, forKey: .dims) ?? isLight
        self.extended = try container.decodeIfPresent(Bool.self, forKey: .extended) ?? false
        self.preset = try container.decodeIfPresent(Bool.self, forKey: .preset) ?? false
        self.universalAllLightsOn = try container.decodeIfPresent(Bool.self, forKey: .universalAllLightsOn) ?? false
        self.universalAllLightsOff = try container.decodeIfPresent(Bool.self, forKey: .universalAllLightsOff) ?? false
        self.universalAllUnitsOff = try container.decodeIfPresent(Bool.self, forKey: .universalAllUnitsOff) ?? false
    }
}
