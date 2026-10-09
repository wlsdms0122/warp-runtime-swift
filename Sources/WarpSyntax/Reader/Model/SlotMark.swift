//
//  SlotMark.swift
//  WarpSyntax
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Warp

// What a slot may write in front of a whole type, and how this notation
// spells it. The two do not stand in the same place (`var` is a field's and
// `inout` a parameter's), but a document writes them the same way, so the
// spelling is said once here and the reading, the writing and the document's
// own vocabulary come off it.
//
// The language's own record of which types are marked is the cases of
// `TypeExpression`. What is here is their spelling, which is this notation's
// and not something a caller assembling a `TypeExpression` in Swift ever needs.
enum SlotMark: String, CaseIterable, Sendable {
    case variable = "var"
    case `inout`

    // MARK: - Property
    // The mark as it stands in front of a spelling. The reading takes this off
    // the front and the writing puts it there, so the shape of a marked
    // spelling is said once.
    var front: String { "\(rawValue) " }

    // MARK: - Initializer
    // MARK: - Public
    // The mark a type was written under, where it was written under one.
    //
    // No `default`: a type nobody thought about has to be a compile error here
    // rather than an answer of "unmarked", which is the answer every reading of
    // a marked slot would then get.
    static func marked(_ type: TypeExpression) -> SlotMark? {
        switch type {
        case .variable:
            return .variable

        case .inout:
            return .inout

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .record, .procedure, .nullable, .named, .parameter,
            .projection, .composition, .selfType:
            return nil
        }
    }

    // The mark a spelling begins with, and the spelling under it. The other
    // half of `marked(_:)`: one asks a type that has been made, this asks text
    // that has not been read yet, and a mark stands in front of a whole
    // spelling so the question is the same one twice.
    static func leading(of text: String) -> (mark: SlotMark, rest: String)? {
        for mark in allCases {
            guard text.hasPrefix(mark.front) else { continue }

            return (mark, String(text.dropFirst(mark.front.count)))
        }

        return nil
    }

    func marking(_ spelling: String) -> String {
        "\(front)\(spelling)"
    }

    // The type a slot marked this way holds.
    func marking(_ inner: TypeExpression) -> TypeExpression {
        switch self {
        case .variable:
            return .variable(inner)

        case .inout:
            return .inout(inner)
        }
    }

    // MARK: - Private
}
