//
//  ContractProcedure.swift
//  Warp
//
//  Created by JSilver on 9/21/26.
//

import Foundation

// One procedure a contract asks: what a call may hand it and what it answers,
// and what every declaration answering it is held to beyond that. A contract
// may ask that the procedure answers without running, or touches no name
// another body could touch at once, the way a slot asks it of a procedure;
// a call through the contract then reads as the contract says, and a claim
// backed by a declaration that does less does not hold.
//
// No bounds: the bound a type parameter carries is the declaring signature's
// own.
public struct ContractProcedure: Sendable, Equatable {
    // MARK: - Property
    public let signature: Signature
    public let constness: Constness
    public let isolation: Isolation

    // MARK: - Initializer
    public init(signature: Signature = Signature(), constness: Constness = .unstated, isolation: Isolation = .unstated) {
        self.signature = signature
        self.constness = constness
        self.isolation = isolation
    }

    // MARK: - Public
    // MARK: - Private
}
