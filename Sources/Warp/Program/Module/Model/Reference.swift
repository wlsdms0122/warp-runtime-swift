//
//  Reference.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// One thing a link resolves to a declarer. A document declares some of these
// and leans on others, and the same question is asked of every one: which
// document in this list declares it.
//
// The kind is part of the value, so a procedure and a type spelled alike are
// two references. Types and contracts are one namespace: a link refuses a
// name standing for a type and a contract at once, and says nothing about a
// procedure spelled like a type.
//
// A claim declares no name, so a document stands on the one making it by the
// pair it is about: one document making it supplies it, and one importing it
// references it. Several may make one claim, and any of them answers.
enum Reference: Hashable, Sendable, Comparable {
    case procedure(Name)
    case type(Name)
    case claim(ClaimPair)

    // MARK: - Property
    // How a sentence names what is referenced, without the kind.
    var spelling: String {
        switch self {
        case let .procedure(name), let .type(name): name.spelling
        case let .claim(pair): pair.spelling
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Procedures, then types, then claims, and each in name order. The module
    // graph walks a module's needs in this order, so which cycle it refuses is
    // a fact of the modules.
    static func < (lhs: Reference, rhs: Reference) -> Bool {
        switch (lhs, rhs) {
        case let (.procedure(left), .procedure(right)), let (.type(left), .type(right)):
            return left < right

        case let (.claim(left), .claim(right)):
            return left < right

        default:
            return lhs.rank < rhs.rank
        }
    }

    // MARK: - Private
    private var rank: Int {
        switch self {
        case .procedure: 0
        case .type: 1
        case .claim: 2
        }
    }
}
