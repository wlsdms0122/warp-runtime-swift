//
//  Fanout.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation
import Warp
import WarpStandard

// Words that call nothing, dealt into a given number of documents, with the two
// halves of a build timed apart.
//
// A build compiles and then links. Compiling settles what a document says
// against what it reaches, and a word here reaches nothing outside the document
// it is written in, so each document's compile is a question about that
// document alone. Linking lays the compiled documents down together and is one
// question about the whole list. Dealing the same words into more documents
// moves work from the second question into the first without changing how much
// work there is.
//
// That is what the counts are read for. `alone()` is what the documents cost
// compiled one at a time, so `alone()` over the document count is what a build
// spreading them across as many cores as it has documents would leave on one,
// and `link()` is what no spreading takes away. What `alone()` costs over
// `compile()` is what a compile stops sharing once the documents are split.
//
// A chain answers none of this: its documents stand in a line, so a document
// cannot be compiled until the one in front of it has been. `Chain` is the
// world where that line is what is being measured.
struct Fanout {
    // MARK: - Property
    let words: Int
    let documents: Int

    private let modules: [Module]
    private let entry: Name

    // MARK: - Initializer
    init(of words: Int, across documents: Int) throws {
        guard words > 0 else { throw Refusal.wordless }
        guard 1 ... words ~= documents else { throw Refusal.undealable }

        self.words = words
        self.documents = documents
        self.entry = try Self.word(0)
        self.modules = try (0 ..< documents).map { document in
            try Self.document(Self.held(by: document, of: words, across: documents))
        }
    }

    // MARK: - Public
    // How long compiling these documents and then linking them takes.
    func build() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            _ = try builder.link(
                Vocabulary.compiled + builder.compile(
                    modules,
                    against: Vocabulary.compiled,
                    supplying: Vocabulary.brought
                ),
                entry: entry,
                supplying: Vocabulary.brought
            )
        }
    }

    // How long compiling every document together takes.
    func compile() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            _ = try builder.compile(modules, against: Vocabulary.compiled, supplying: Vocabulary.brought)
        }
    }

    // How long the same documents cost compiled one at a time, added up.
    func alone() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            for module in modules {
                _ = try builder.compile([module], against: Vocabulary.compiled, supplying: Vocabulary.brought)
            }
        }
    }

    // How long laying the compiled documents down together takes.
    func link() throws -> Duration {
        let builder = Builder()
        let compiled = Vocabulary.compiled + (try builder.compile(
            modules,
            against: Vocabulary.compiled,
            supplying: Vocabulary.brought
        ))

        return try elapsed {
            _ = try builder.link(compiled, entry: entry, supplying: Vocabulary.brought)
        }
    }

    // MARK: - Private
    private enum Refusal: Error {
        // A world of no words holds nothing to start a build from.
        case wordless

        // Fewer documents than one, or more documents than there are words to
        // put in them: either way a document is left with nothing.
        case undealable
    }

    private static func word(_ number: Int) throws -> Name { try Name("fanout.word\(number)") }

    private static func shape(_ number: Int) throws -> Name { try Name("fanout.Word\(number)") }

    // The run of words a document holds, so that every document holds as near
    // the same count as the counts divide into.
    private static func held(by document: Int, of words: Int, across documents: Int) -> Range<Int> {
        (document * words / documents) ..< ((document + 1) * words / documents)
    }

    // One document: a type for each word it holds, and each word standing on
    // its own type and answering what it was sent. It imports nothing, which is
    // what leaves its compile a question about itself.
    private static func document(_ held: Range<Int>) throws -> Module {
        var types: [Name: TypeExpression] = [:]
        var procedures: [Name: Procedure] = [:]

        for number in held {
            types[try shape(number)] = .record(["value": .int])
            procedures[try word(number)] = try procedure(number)
        }

        return try Module(imports: [], types: types, procedures: procedures)
    }

    private static func procedure(_ number: Int) throws -> Procedure {
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
            result: held
        )
    }
}
