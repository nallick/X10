//
//  StringExtensions.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension String {

    internal func camelCased() -> String {
        guard let firstChar = self.first else { return "" }
        return firstChar.lowercased() + self.dropFirst()
    }

    internal func titleCased() -> String {
        guard let firstChar = self.first else { return "" }
        return firstChar.uppercased() + self.dropFirst()
    }
}
