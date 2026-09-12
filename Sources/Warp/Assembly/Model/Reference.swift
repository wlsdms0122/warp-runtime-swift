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
// The kind is part of the value, so a procedure and a shape spelled alike are two
// references. A link refuses a name standing for a shape and a membership at
// once and says nothing about a procedure spelled like a type.
enum Reference: Hashable, Sendable, Comparable {
    case procedure(Name)
    case shape(Name)

    // MARK: - Internal
    // Procedures before shapes, and each in name order. A catalogue reports the
    // first collision it walks into, so this is the order an author meets
    // them in.
    static func < (lhs: Reference, rhs: Reference) -> Bool {
        switch (lhs, rhs) {
        case let (.procedure(left), .procedure(right)), let (.shape(left), .shape(right)):
            return left < right

        case (.procedure, .shape):
            return true

        case (.shape, .procedure):
            return false
        }
    }

    // What a sentence calls this kind where it names one.
    var noun: String {
        switch self {
        case .procedure: "procedure"
        case .shape: "shape"
        }
    }

    // The name itself, for the tables and sentences that want it without the
    // kind.
    var name: Name {
        switch self {
        case let .procedure(name), let .shape(name): name
        }
    }
}
