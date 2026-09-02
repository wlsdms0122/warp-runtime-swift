//
//  Notation.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// What a notation offers on top of the document, the way `ConstructRegistry`
// says which construct words it offers.
//
// A spelling stands in for something the language already has: a condition
// written as an operator is a message, and so is a template. So a document has
// two layers, and this is the switch between them — a notation brings its own
// spellings, and the canonical one brings none, which leaves a document writing
// the shapes themselves.
//
// **Nothing built in offers a spelling, and nothing here names one.** This
// package reads documents; a document has no spellings, so a reader carrying a
// table of them would be a reader with a notation's opinions. Which keys are
// spelled, which words they reach, and what the record around them looks like
// are all answered by whoever hands one of these over.
//
// That is worth insisting on because the lower layer is what travels. A program
// read somewhere else needs that reader to agree about what it says, and each
// spelling is one more rule the far side has to implement identically. A
// notation that offers none owes no words for spellings it never spends.
//
public struct Notation: Sendable {
    // MARK: - Property
    // Nothing stood in for. Every condition is the expression it is written as,
    // and text is put together by sending the words that put text together.
    //
    // This is what a document is read with, and it is the only one this package
    // ships — the others are notations, and a notation lives where it does.
    public static let canonical = Notation()

    // How a condition slot may be written here, and nothing where a condition is
    // written as the expression it is.
    public let condition: (any ConditionSpelling)?

    // What `{ format:, with: }` lowers to, and nothing where this notation does
    // not offer a template.
    //
    // The two keys stay reserved either way — that much is the document's, and
    // the specification says so. What varies is only whether a template is
    // understood, and which words it spends.
    public let interpolation: Interpolation?

    // What these spellings spend no matter which constructs exist. A template is
    // written in a value slot and every construct has one, so offering it owes
    // these wherever the notation is used.
    //
    // A condition's words are not here: a condition is read through `when` and
    // `while`, so a notation with neither spends nothing on them however many it
    // offers. The forms that read one ask for them by name, below.
    public var vocabulary: Set<String> {
        guard let interpolation else { return [] }

        return [interpolation.read, interpolation.joined]
    }

    // What a condition slot spends, for the forms that have one. Answered here
    // rather than assembled by each of them, so that whether a notation has a
    // condition spelling at all stays this type's business.
    public var conditionVocabulary: Set<String> {
        condition?.vocabulary ?? []
    }

    // MARK: - Initializer
    public init(
        condition: (any ConditionSpelling)? = nil,
        interpolation: Interpolation? = nil
    ) {
        self.condition = condition
        self.interpolation = interpolation
    }

    // MARK: - Public
    // Giving up the template. The words it stood for are still reachable by
    // sending them, which is the whole reason a spelling can be given up at all.
    public func removingInterpolation() -> Notation {
        Notation(condition: condition, interpolation: nil)
    }

    // MARK: - Private
}
