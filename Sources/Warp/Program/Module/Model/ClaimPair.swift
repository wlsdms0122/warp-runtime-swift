//
//  ClaimPair.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// The pair a claim is about: a type and a contract it answers. What a document
// names where it imports a claim another document makes, so that the claim is
// among what it stands on: a claim declares no name, and a document reaches
// another only through what it names.
//
// The type and not the head. A document using a claim asks whether a type
// answers a contract, and which values the claim's head takes is the claim's.
public struct ClaimPair: Hashable, Comparable, Sendable, CustomStringConvertible {
    // MARK: - Property
    public let type: Name
    public let contract: Name

    // How a document writes it among its imports.
    public var spelling: String {
        "\(type.spelling): \(contract.spelling)"
    }

    public var description: String { spelling }

    // MARK: - Initializer
    public init(_ type: Name, _ contract: Name) {
        self.type = type
        self.contract = contract
    }

    // MARK: - Public
    public static func < (lhs: ClaimPair, rhs: ClaimPair) -> Bool {
        (lhs.type, lhs.contract) < (rhs.type, rhs.contract)
    }

    // MARK: - Private
}
