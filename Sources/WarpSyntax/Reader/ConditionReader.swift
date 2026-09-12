//
//  ConditionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A condition slot. In a document it holds an expression that must answer a
// bool, and that is the whole of it. `when` and `while` take what any value
// slot takes, and nothing about a condition is written differently from
// anything else.
//
// The slot exists as a type of its own because a notation may write one
// specially: an operator key and its subject, a connective over conditions, a
// procedure that takes its expression directly. Every part of that (including which
// keys are operators at all, and the `of` they are written beside) belongs to
// the notation, so this asks the notation and reads an expression when there is
// none or when the record is not one of its.
//
// A table of operator keys here would give a document's condition slot a grammar
// the specification does not give it, and would leave the front end that spells
// those procedures unable to replace any of it.
public struct ConditionReader: Decodable {
    // MARK: - Property
    public let condition: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let notation = decoder.userInfo[.notation] as? Notation ?? .canonical

        // Read as the expression it is, through the ordinary entry point rather
        // than the reading behind it, so that a bad expression here says where
        // it is the way one in any other slot does.
        guard let spelling = notation.condition else {
            self.condition = try ExpressionReader(from: decoder).expression

            return
        }

        // A spelling is recognised by the key it is written under. Anything
        // else in this slot never was one. It is an expression, and reading it
        // as one is what keeps these spellings optional.
        //
        // A form key wins, and this is the one place the order has to be said
        // out loud. The form keys are fixed and read wherever data appears, so
        // `{ as: <type>, of: <value> }` is a cast in every notation, but a
        // notation that recognises its conditions by a subject key sees the
        // `of` and claims the record, and what it makes of the `as` beside it
        // is a message nobody wrote. The same document would be a cast in one
        // notation and a send in the next.
        guard
            let written = try ValueReader(from: decoder).value.asDictionary,
            Set(written.names).isDisjoint(with: ExpressionReader.formKeys),
            !Set(written.names).isDisjoint(with: spelling.keys)
        else {
            self.condition = try ExpressionReader(from: decoder).expression

            return
        }

        self.condition = try spelling.condition(from: decoder)
    }

    // MARK: - Public
    // MARK: - Private
}
