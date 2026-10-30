//
//  Construct.swift
//  Warp
//
//  Created by JSilver on 9/1/26.
//

import Foundation

// Which construct an expression is, without any of it.
//
// A place says which construct a statement writes, and the construct is the
// whole of what it has to say. Carrying the expression would put a program
// inside an address. The cases are the language's own and no document's: the
// key a document writes a construct under is the reader's.
public enum Construct: Sendable, Hashable {
    case literal
    case reference
    case array
    case `struct`
    case dictionary
    case closure
    case cast

    case conditional
    case loop
    case `try`
    case unwrap
    case call
    case leave(Leave.Reach)

    // MARK: - Property
    // What the language calls this construct. A document calls several of them
    // something else, and the reading that knows which is not this one.
    //
    // Leaving renders as one name for all three reaches. Which loop a `leave`
    // ends is carried in the case and spelled by whoever spells for a document.
    // An address exists to reach the statement, and the statement is already
    // named a step above.
    public var rendered: String {
        switch self {
        case .literal: "literal"
        case .reference: "reference"
        case .array: "array"
        case .struct: "struct"
        case .dictionary: "dictionary"
        case .closure: "closure"
        case .cast: "cast"
        case .conditional: "conditional"
        case .loop: "loop"
        case .try: "try"
        case .unwrap: "unwrap"
        case .call: "call"
        case .leave: "leave"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
