//
//  StateBroker.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

extension X10 {

    /// A broker topic can a request or a state update.
    ///
    public enum TopicType {
        case request, state
    }

    /// A broker topic can have multiple variations.
    ///
    public enum TopicVariation: String {

        case level = "Level"
        case power = "On"
    }

    public static var stateBrokerTopicPrefix = "X10/"
    public static var stateBrokerTopicStatePrefix = X10.stateBrokerTopicPrefix + "State/"
    public static var stateBrokerTopicRequestPrefix = X10.stateBrokerTopicPrefix + "Request/"
}

extension X10.Address {

    /// Return the broker topic for the level variation of the receiver.
    ///
    public var brokerTopicLevelState: String {
        return X10.stateBrokerTopicStatePrefix + "\(self.description)-\(X10.TopicVariation.level.rawValue)"
    }

    /// Return the broker topic for the power variation of the receiver.
    ///
    public var brokerTopicPowerState: String {
        return X10.stateBrokerTopicStatePrefix + "\(self.description)-\(X10.TopicVariation.power.rawValue)"
    }
}

extension X10.Instruction {

    /// Initialize an instruction with a broker topic and payload.
    ///
    /// - Parameter topic: The broker topic.
    /// - Parameter payload: The broker payload.
    ///
    public init?(topic: String, payload: String) {
        guard let instruction = topic.x10TopicInstruction else { return nil }
        let splitInstruction = instruction.split(separator: "-").map { String($0) }
        guard splitInstruction.count == 2,
            let address = X10.Address(rawValue: splitInstruction[0]),
            let payloadValue = Int(payload)
            else { return nil }

        let variationString = String(splitInstruction[1])
        switch X10.TopicVariation(rawValue: variationString) {
            case .some(.power):
                self.init(address: address, command: (payloadValue == 0) ? .off : .on)
            case .some(.level):
                guard let message = X10.Message(address: address, level: payloadValue, environment: X10.shared.environment) else { return nil }
                self.init(address: address, message: message)
            case .none:
                guard address.isHouseAddress, let command = X10.CommandCode.named(variationString.camelCased()), command.isHouseCommand else { return nil }
                let message = X10.Message(house: address.house, command: command)
                self.init(address: address, message: message)
        }
    }
}

extension String {

    public var x10TopicType: X10.TopicType? {
        if self.hasPrefix(X10.stateBrokerTopicRequestPrefix) { return .request }
        if self.hasPrefix(X10.stateBrokerTopicStatePrefix) { return .state }
        return nil
    }

    public var x10TopicInstruction: String? {
        if self.hasPrefix(X10.stateBrokerTopicRequestPrefix) { return String(self.dropFirst(X10.stateBrokerTopicRequestPrefix.count)) }
        if self.hasPrefix(X10.stateBrokerTopicStatePrefix) { return String(self.dropFirst(X10.stateBrokerTopicStatePrefix.count)) }
        return nil
    }
}
