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
// another body could touch at once, the way a slot asks it of a procedure,
// and says what the procedure may fail with; a call through the contract then
// reads as the contract says, and a claim backed by a declaration that does
// less, or fails with more, does not hold.
public struct ContractProcedure: Sendable, Equatable {
    // MARK: - Property
    public let signature: Signature
    public let constness: Constness
    public let isolation: Isolation

    // What a declaration answering it may fail with, and so what a call
    // through the contract may. Nothing, unless the contract names some.
    public let failing: Set<String>

    // MARK: - Initializer
    public init(
        signature: Signature = Signature(),
        constness: Constness = .unstated,
        isolation: Isolation = .unstated,
        failing: Set<String> = []
    ) {
        self.signature = signature
        self.constness = constness
        self.isolation = isolation
        self.failing = failing
    }

    // MARK: - Public

    // MARK: - Private
}
