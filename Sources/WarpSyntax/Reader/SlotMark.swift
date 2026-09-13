//
//  SlotMark.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// What a slot may write in front of a whole type, and how this notation spells
// it. The marks do not all stand in the same place (`var` is a field's and the
// other three a parameter's) and they do not all survive lowering, but a
// document writes them all the same way, so the spelling is said once here and
// the reading, the writing and the document's own vocabulary come off it.
//
// The language's own record of which types are marked is the cases of
// `TypeExpression`. What is here is their spelling, which is this notation's
// and not something a caller assembling a `TypeExpression` in Swift ever needs.
enum SlotMark: String, CaseIterable, Sendable {
    case variable = "var"
    case `inout`
    case consuming
    case borrowing

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The mark a type was written under, and the type under it.
    //
    // No `default`: a type nobody thought about has to be a compile error here
    // rather than an answer of "unmarked", which is the answer every reading of
    // a marked slot would then get.
    static func marked(_ type: TypeExpression) -> (mark: SlotMark, inner: TypeExpression)? {
        switch type {
        case let .variable(inner):
            return (.variable, inner)

        case let .inout(inner):
            return (.inout, inner)

        case let .consuming(inner):
            return (.consuming, inner)

        case let .borrowing(inner):
            return (.borrowing, inner)

        case .any, .never, .null, .bool, .int, .double, .string, .bytes, .number, .ranged,
            .array, .dictionary, .record, .procedure, .linear, .nullable, .named, .parameter,
            .reading:
            return nil
        }
    }

    // The type a slot marked this way holds.
    func marking(_ inner: TypeExpression) -> TypeExpression {
        switch self {
        case .variable:
            return .variable(inner)

        case .inout:
            return .inout(inner)

        case .consuming:
            return .consuming(inner)

        case .borrowing:
            return .borrowing(inner)
        }
    }

    // MARK: - Private
}
