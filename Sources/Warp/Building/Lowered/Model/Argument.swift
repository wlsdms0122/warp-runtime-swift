//
//  Argument.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// One argument of a call, lowered on its own.
//
// What the argument is and which slot takes it are two facts. A call through a
// contract writes one argument list and has as many callees as there are types
// answering the procedure, so the list is lowered once and placed against each.
enum Argument: Sendable {
    case value(Operation)

    // A name handed in place, kept as the place rather than as a read of it:
    // a slot taking it in place takes the slot holding it and the path below.
    case reference(Address)

    // MARK: - Property
    // The argument read as a value, for a slot that does not take it in place.
    var read: Operation {
        switch self {
        case let .value(operation):
            return operation

        case let .reference(address):
            return .local(address)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Argument {
        switch self {
        case let .value(held):
            return .value(try held.rewritten(operation: operation, type: type))

        case .reference:
            return self
        }
    }

    // MARK: - Private
}
