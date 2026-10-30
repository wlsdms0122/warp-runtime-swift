//
//  Existential.swift
//  Warp
//
//  Created by JSilver on 10/23/26.
//

import Foundation

// A value read as a contract, with the type it was read as: what a call
// through the contract picks by and what a cast to a contract judges. A
// native procedure is handed the type with the value and hands it back as it
// came, and a fold keeps it. The type drops only where the value meets `Any`
// and where the run hands the host its result, and sameness, `text` and a
// dictionary's keys read the value alone. A host reads the value and hands
// the box on, and makes none.
public struct Existential: Sendable {
    // The type it holds. One a variable's start or an object holds stands
    // spelled as a document writes a type, by name, since a type's number is
    // its table's; the link reads it in its own. One a run made, a
    // fold's included, stands read in that run's table.
    enum Resolution: Sendable {
        case spelled(TypeExpression)
        case resolved(LoweredType)
    }

    // MARK: - Property
    public let value: Value
    let resolution: Resolution

    // MARK: - Initializer
    init(_ value: Value, as type: LoweredType) {
        self.init(value, resolution: .resolved(type))
    }

    init(_ value: Value, resolution: Resolution) {
        self.value = value
        self.resolution = resolution
    }

    // MARK: - Public
    // The type it holds, read in the run's table. A value reaches a run only
    // through a link, so one holding a type spelled is one no link read.
    func resolved() throws -> LoweredType {
        guard case let .resolved(type) = resolution else {
            throw ExecutionError("a value held beside a type no link read")
        }

        return type
    }

    // The same value with the type it holds spelled, read in the table it
    // was numbered in.
    func spelled(in table: LoweredTypeTable) -> Existential {
        guard case let .resolved(type) = resolution else { return self }

        return Existential(value, resolution: .spelled(type.spelled(in: table)))
    }

    // The same value with the type it holds read in a link's table, where it
    // holds one spelled.
    func standing(in table: LoweredTypeTable) -> Existential {
        guard case let .spelled(type) = resolution else { return self }

        return Existential(value, as: type.lowered(in: table))
    }

    // Something else held beside the same type.
    func holding(_ value: Value) -> Existential {
        Existential(value, resolution: resolution)
    }

    // MARK: - Private
}
