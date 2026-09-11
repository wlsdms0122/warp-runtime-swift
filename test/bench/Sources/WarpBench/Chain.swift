//
//  Chain.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Warp
import WarpStandard

// A chain of words, each calling the word in front of it, dealt into a given
// number of documents and linked as many times as asked.
//
// The two counts are the two things a link is asked to carry, and they move
// apart here so that a figure can say which one it is paying for. Hold the
// words and deal them into fewer documents: a link has the same bodies to lower
// and the same names to place, and only the documents are fewer.
//
// A chain rather than words that ignore each other: dealt one to a document,
// the last document depends on every document in front of it, so the dependency
// closures sum to the square of the count while a set that shares nothing keeps
// them at one. That is the count a separate compile carries per document.
//
// The standard vocabulary is linked in the way every other workload links it.
// A document that arrives alone still pays for it, so the counts say when a
// world's own words overtake what one always costs.
struct Chain {
    // MARK: - Property
    let words: Int
    let documents: Int

    private let world: [Module]
    private let entry: Name

    // MARK: - Initializer
    init(of words: Int, across documents: Int) throws {
        guard words > 0 else { throw Refusal.wordless }
        guard 1 ... words ~= documents else { throw Refusal.undealable }

        self.words = words
        self.documents = documents
        self.entry = try Self.step(words - 1)
        self.world = try (0 ..< documents).map { document in
            try Self.document(Self.held(by: document, of: words, across: documents))
        } + Module.standard
    }

    // MARK: - Public
    // How long one build of this world takes.
    func build() throws -> Duration {
        try elapsed { _ = try Builder().build(world, entry: entry) }
    }

    // MARK: - Private
    private enum Refusal: Error {
        // A chain of no words holds nothing to start a build from.
        case wordless

        // Fewer documents than one, or more documents than there are words to
        // put in them: either way a document is left with nothing.
        case undealable
    }

    private static func step(_ number: Int) throws -> Name { try Name("chain.step\(number)") }

    private static func shape(_ number: Int) throws -> Name { try Name("chain.Step\(number)") }

    // The run of words a document holds. Dealt in runs rather than one at a
    // time round the documents, so a document sends exactly one word it does
    // not declare however many documents there are.
    private static func held(by document: Int, of words: Int, across documents: Int) -> Range<Int> {
        (document * words / documents) ..< ((document + 1) * words / documents)
    }

    // One document: a type for each word it holds, and each word standing on
    // its own type and handing what it was sent to the word in front of it.
    // What a word adds is a written body and the type it names, which is what a
    // link pays for a word somebody wrote.
    private static func document(_ held: Range<Int>) throws -> Module {
        let sent = try held.lowerBound > 0 ? [step(held.lowerBound - 1)] : []
        var types: [Name: TypeExpression] = [:]
        var procedures: [Name: Procedure] = [:]

        for number in held {
            types[try shape(number)] = .record(["value": .int])
            procedures[try step(number)] = try word(number)
        }

        return try Module(imports: Set(sent), types: types, procedures: procedures)
    }

    private static func word(_ number: Int) throws -> Procedure {
        let ahead = number > 0 ? try step(number - 1) : nil
        let held = Warp.Expression.reference([.key("held"), .key("value")])

        return Procedure(
            signature: Signature(parameters: ["value": Parameter(type: .int)], returns: .int),
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .cast(
                        .record(["value": .reference([.key("value")])]),
                        as: .named(try shape(number)),
                        optional: false
                    )
                )
            ],
            result: ahead.map { name in .call(Call(selector: name, arguments: ["value": held])) } ?? held
        )
    }
}
