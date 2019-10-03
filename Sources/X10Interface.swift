//
//  X10Interface.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

public enum X10InterfaceStatus: Error {
    case cancelled, connectionClosed, connectionNotOpen, success, switchedToInput, timedOut, unexpectedResponse, writeFailed
}

public protocol X10Interface {

    typealias Completion = (X10InterfaceStatus) -> Void

    /// Broadcast an X10 instruction to the powerline.
    ///
    /// - Parameter instruction: The instruction to broadcast.
    /// - Parameter completion: The closure called after completion (if any).
    ///
    func send(instruction: X10.Instruction, completion: X10Interface.Completion?)
}
