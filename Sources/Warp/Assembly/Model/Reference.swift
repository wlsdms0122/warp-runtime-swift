//
//  Reference.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// One thing a link resolves to a declarer. A document declares some of these
// and leans on others, and the same question is asked of every one: which
// document in this list declares it.
//
// The kind is part of the value, so a procedure and a type spelled alike are
// two references. Types, memberships and contracts are one namespace: a link
// refuses a name standing for a type and a membership at once, and says
// nothing about a procedure spelled like a type.
enum Reference: Hashable, Sendable, Comparable {
    case procedure(Name)
    case type(Name)

    // MARK: - Internal
    // Procedures before types, and each in name order. A catalogue reports the
    // first collision it walks into, so this is the order an author meets
    // them in.
    static func < (lhs: Reference, rhs: Reference) -> Bool {
        switch (lhs, rhs) {
        case let (.procedure(left), .procedure(right)), let (.type(left), .type(right)):
            return left < right

        case (.procedure, .type):
            return true

        case (.type, .procedure):
            return false
        }
    }

    // What a sentence calls this kind where it names one.
    var noun: String {
        switch self {
        case .procedure: "procedure"
        case .type: "type"
        }
    }

    // The name itself, for the tables and sentences that want it without the
    // kind.
    var name: Name {
        switch self {
        case let .procedure(name), let .type(name): name
        }
    }
}
