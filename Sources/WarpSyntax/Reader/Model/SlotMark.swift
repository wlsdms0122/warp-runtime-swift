//
//  SlotMark.swift
//  WarpSyntax
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Warp

// What a slot may write in front of a whole type. The two do not stand in
// the same place (`var` is a field's and `inout` a parameter's), but a
// document writes them the same way, so the shape of a marked spelling is
// said once here and the reading and the writing come off it. The words are
// `TypeSpelling`'s.
//
// The language's own record of which types are marked is the cases of
// `TypeExpression`. What is here is how a spelling carries them, which is this
// notation's and not something a caller assembling a `TypeExpression` in Swift
// ever needs.
enum SlotMark: CaseIterable, Sendable {
    case variable
    case `inout`

    // MARK: - Property
    // The word the mark is written as.
    var word: Name {
        switch self {
        case .variable: TypeSpelling.variable
        case .inout: TypeSpelling.inout
        }
    }

    // The mark as it stands in front of a spelling. The reading takes this off
    // the front and the writing puts it there.
    var front: String { "\(word) " }

    // MARK: - Initializer
    // MARK: - Public
    // The mark a type was written under, where it was written under one.
    // Every case is named, so a new one is a compile error here.
    static func marked(_ type: TypeExpression) -> SlotMark? {
        switch type {
        case .variable:
            return .variable

        case .inout:
            return .inout

        case .any, .never, .null, .bool, .int, .double, .string,
            .array, .dictionary, .procedure, .nullable, .named, .parameter,
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
