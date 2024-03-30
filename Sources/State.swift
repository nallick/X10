//
//  State.swift
//
//  Copyright © 2019, 2024 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    /// The state of an X10 device consisting of the power on/off and the brightness level.
    ///
    public struct State: Equatable {
        public enum Status: Error {
            case invalidNotation
        }

        public var on: Bool
        public var level: Int

        /// Initialize state with power and brightness level.
        ///
        /// - Parameter on: The power state.
        /// - Parameter level: The brightness level state.
        ///
        public init(on: Bool = false, level: Int = 100) {
            self.on = on
            self.level = level
        }

        /// Initializes state from string notation.
        ///
        /// - Parameter notation: The notation of an state.
        ///
        /// - Throws: Status.invalidNotation
        ///
        public init(_ notation: String) throws {
            let splitNotation = notation.split(separator: "-").map { String($0) }
            guard splitNotation.count == 2, let level = Int(splitNotation[1]), level >= 0, level <= 100 else { throw Status.invalidNotation }
            let isOn = (splitNotation[0] == "ON")
            guard isOn || splitNotation[0] == "OFF" else { throw Status.invalidNotation }

            self.on = isOn
            self.level = level
        }

        /// Determine if the receiver's state matches a level as specified for a scene.
        ///
        /// - Parameter sceneLevel: The scene level to test against.
        ///
        /// - Returns: `true` is the level matches this state; `false` otherwise.
        ///
        public func matchesSceneLevel(_ sceneLevel: Int) -> Bool {
            if sceneLevel == 0 && !self.on { return true }
            return self.on && sceneLevel == self.level
        }
    }
}

extension X10.State: RawRepresentable {

    public typealias RawValue = String

    /// State can be represented by a string "ON" or "OFF" and the brightness level".
    ///
    public var rawValue: String {
        return self.description
    }

    /// Initialize state with its description.
    ///
    /// - Parameter rawValue: The string containing the state notation.
    ///
    public init?(rawValue: String) {
        try? self.init(rawValue)
    }
}

extension X10.State: CustomStringConvertible {

    /// Returns a description of the receiver as a string.
    ///
    public var description: String {
        return "\(self.on ? "ON" : "OFF")-\(self.level)"
    }
}

extension X10.HouseCode {

    /// The current selection of any house code is a set of device numbers.
    ///
    public struct Selection {
        public private(set) var selection: Set<Int> = []
        private var selectionClosed = false

        /// Select a device.
        ///
        /// - Parameter device: The device to select.
        ///
        public mutating func select(_ device: Int) {
            if self.selectionClosed {
                self.selection = [device]
                self.selectionClosed = false
            } else {
                self.selection.insert(device)
            }
        }

        /// Deselect all devices.
        ///
        public mutating func deselectAll() {
            self.selection.removeAll()
            self.selectionClosed = false
        }

        /// Close the receiver causing the next selection attempt to reset the selection.
        ///
        public mutating func closeSelection() {
            self.selectionClosed = true
        }
    }
}

extension X10.HouseCode.Selection: CustomStringConvertible {

    /// Returns a description of the receiver as a string.
    ///
    public var description: String {
        return "<\(self.selection), \(self.selectionClosed ? "closed" : "open")>"
    }
}
