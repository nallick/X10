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

    public struct ParsedTopic {
        public let address: Address
        public let value: Int
        public let variation: TopicVariation?
        public let command: String

        /// Parse a broker topic and payload.
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

            self.command = String(splitInstruction[1])
            self.address = address
            self.value = payloadValue
            self.variation = X10.TopicVariation(rawValue: self.command)
        }
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
        guard let parsedTopic = X10.ParsedTopic(topic: topic, payload: payload) else { return nil }
        self.init(parsedTopic: parsedTopic)
    }

    /// Initialize an instruction with a parsed broker topic.
    ///
    /// - Parameter parsedTopic: The parsed broker topic.
    ///
    public init?(parsedTopic: X10.ParsedTopic) {
        switch parsedTopic.variation {
            case .some(.power):
                self.init(address: parsedTopic.address, command: (parsedTopic.value == 0) ? .off : .on)
            case .some(.level):
                guard let message = X10.Message(address: parsedTopic.address, level: parsedTopic.value, environment: X10.shared.environment) else { return nil }
                self.init(address: parsedTopic.address, message: message)
            case .none:
                guard parsedTopic.address.isHouseAddress,
                      let command = X10.CommandCode.named(parsedTopic.command.camelCased()),
                      command.isHouseCommand
                    else { return nil }
                let message = X10.Message(house: parsedTopic.address.house, command: command)
                self.init(address: parsedTopic.address, message: message)
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
