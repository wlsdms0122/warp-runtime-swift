//
//  Notation.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// What a notation offers on top of the document, the way `ConstructRegistry`
// says which construct keys it offers.
//
// A spelling stands in for something the language already has: a condition
// written as an operator is a message, and so is a template. So a document has
// two layers, and this is the switch between them. A notation brings its own
// spellings, and the canonical one brings none, which leaves a document writing
// the types themselves.
//
// **Nothing built in offers a spelling.** This package reads documents, and a
// document has no spellings. Which keys are spelled, which procedures they
// reach, and what the record around them looks like are all answered by whoever
// hands one of these over. The one set of keys named here is the template's,
// `format` and `with`, which stay reserved whether a notation offers a template
// or not. A notation that offers none owes no procedures for spellings it never
// spends.
public struct Notation: Sendable {
    // Where a declared name stands: the types and contracts a type
    // spelling, a bound or a claim names, or the
    // procedures a call names. A text may declare one name in both, and the
    // reader that asks says which it is reading.
    public enum Space: Sendable {
        case type
        case procedure
    }

    // MARK: - Property
    // Nothing stood in for. Every condition is the expression it is written as,
    // and text is put together by sending the procedures that put text together.
    //
    // This is what a document is read with, and it is the only one this package
    // ships. The others are notations, and a notation lives where it does.
    public static let canonical = Notation()

    // How an expression may be written here beyond the forms every document
    // has, and nothing where every expression is written as the expression it
    // is.
    public let spelling: (any ExpressionSpelling)?

    // What `{ format:, with: }` lowers to, and nothing where this notation does
    // not offer a template.
    //
    // The two keys stay reserved either way. That much is the document's, and
    // the specification says so. What varies is only whether a template is
    // understood, and which procedures it spends.
    public private(set) var interpolation: Interpolation?

    // Whether a mapping with no tag of its own is a record: where a value is
    // wanted, a record of expressions, and where a type is, a record type. A
    // document writes a record under `record`.
    public let readsBareRecords: Bool

    // Whether a parameter may be written as one pair, `count: Int` for
    // `{ name: count, type: int }` and `count: { type: int, enum: [1, 2] }`
    // for the record with the name inside. A document writes the record.
    public let pairedParameter: Bool

    // What a declared name the text writes stands for, where the text writes
    // one short: a type's name in a slot, a cast, a field, a bound or a
    // claim, and a procedure's name in a call. Nothing for a name the
    // text does not declare. A document writes every name full, so a document
    // qualifies nothing; a notation that lets a text name its own declarations
    // short answers here, and the readers that know where a name stands ask
    // it there.
    public private(set) var qualifying: (@Sendable (Name, Space) -> Name?)?

    // What these spellings spend no matter which constructs exist. A template
    // and a spelling are written in a value slot and every construct has one,
    // so offering either owes these wherever the notation is used.
    public var vocabulary: Set<Name> {
        var owed = spelling?.vocabulary ?? []

        if let interpolation {
            owed.formUnion([interpolation.read, interpolation.joined])
        }

        return owed
    }

    // MARK: - Initializer
    public init(
        spelling: (any ExpressionSpelling)? = nil,
        interpolation: Interpolation? = nil,
        pairedParameter: Bool = false,
        readsBareRecords: Bool = false
    ) {
        self.spelling = spelling
        self.interpolation = interpolation
        self.pairedParameter = pairedParameter
        self.readsBareRecords = readsBareRecords
    }

    // MARK: - Public
    // A declared name as this notation reads it: what the text's declaration
    // is called, or the name as written where the text declares none there.
    public func qualified(_ name: Name, as space: Space) -> Name {
        qualifying?(name, space) ?? name
    }

    // Whether the text read with this notation declares the name there.
    public func declares(_ name: Name, as space: Space) -> Bool {
        qualifying?(name, space) != nil
    }

    // This notation reading names the way `rule` says: what a text declares
    // short is read full by the readers that meet a declared name.
    public func qualifying(_ rule: @escaping @Sendable (Name, Space) -> Name?) -> Notation {
        var copy = self
        copy.qualifying = rule

        return copy
    }

    // Giving up the template. The procedures it stood for are still reachable by
    // sending them, which is the whole reason a spelling can be given up at all.
    public func removingInterpolation() -> Notation {
        var copy = self
        copy.interpolation = nil

        return copy
    }

    // MARK: - Private
}
