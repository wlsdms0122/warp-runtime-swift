//
//  CharactersQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

// The text as an array of its characters, each one a string of its own.
//
// Answered once for the whole text rather than read a character at a time: a
// character is an extended grapheme cluster, so where the tenth one starts is
// only known by walking the nine in front of it, and a body reading them in
// order would pay that walk every round.
struct CharactersQuery: Query {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("Standard.Text.characters asks a string")
        }

        return .array(text.map { character in .string(String(character)) })
    }

    // MARK: - Private
}
