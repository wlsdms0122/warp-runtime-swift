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
    private let modules: [Module]
    private let entry: Name

    // The same documents already compiled, which is what `link()` is handed.
    // What that door times is the laying down, so settling the documents again
    // for every sample would only be time spent outside the clock.
    private let compiled: [Compiled]

    // MARK: - Initializer
    init(_ dealing: Dealing) throws {
        let modules = try (0 ..< dealing.documents).map { document in
            try Self.document(dealing.held(by: document))
        }

        self.entry = try Self.word(0)
        self.modules = modules
        self.compiled = Vocabulary.laid.compiled + (try Builder().compile(
            modules,
            against: Vocabulary.laid
        ))
    }

    // MARK: - Public
    // How long compiling these documents and then linking them takes.
    func build() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            _ = try builder.link(
                Vocabulary.laid.compiled + builder.compile(modules, against: Vocabulary.laid),
                entry: entry,
                supplying: Vocabulary.brought
            )
        }
    }

    // How long compiling every document together takes.
    func compile() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            _ = try builder.compile(modules, against: Vocabulary.laid)
        }
    }

    // How long the same documents cost compiled one at a time, added up.
    func alone() throws -> Duration {
        let builder = Builder()

        return try elapsed {
            for module in modules {
                _ = try builder.compile([module], against: Vocabulary.laid)
            }
        }
    }

    // How long laying the compiled documents down together takes.
    func link() throws -> Duration {
        try elapsed {
            _ = try Builder().link(compiled, entry: entry, supplying: Vocabulary.brought)
        }
    }

    // MARK: - Private
    private static func word(_ number: Int) throws -> Name { try Name("fanout.word\(number)") }

    private static func shape(_ number: Int) throws -> Name { try Name("fanout.Word\(number)") }

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
