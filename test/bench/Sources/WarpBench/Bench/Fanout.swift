//
//  Fanout.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation
import Warp
import WarpStandard

// Procedures that call nothing, dealt into a given number of documents, with
// the two halves of a build timed apart.
//
// A build compiles and then links. Compiling judges what a document says
// against what it reaches, and a procedure here reaches nothing outside the document
// it is written in, so each document's compile is a question about that
// document alone. Linking lays the compiled documents down together and is one
// question about the whole list. Dealing the same procedures into more documents
// moves work from the second question into the first without changing how much
// work there is.
//
// That is what the counts are read for. `alone()` is what the documents cost
// compiled one at a time, so `alone()` over the document count is what a build
// spreading them across as many cores as it has documents would leave on one,
// and `link()` is what no spreading takes away. What `alone()` costs over
// `compile()` is what a compile stops sharing once the documents are split.
//
// `Chain` measures documents that stand in a line, where a document is
// compiled only after the one in front of it.
struct Fanout {
    // MARK: - Property
    private let modules: [Module]

    // The same documents already compiled, which is what `link()` is handed.
    // What that entry point times is the laying down, so the documents are
    // compiled once, outside the clock.
    private let compiled: [Compiled]

    // The vocabulary these were compiled against, held so that every entry
    // point times the same build rather than making it again.
    private let vocabulary: Vocabulary

    // MARK: - Initializer
    init(_ dealing: Dealing) async throws {
        let modules = try (0 ..< dealing.documents).map { document in
            try Self.document(dealing.held(by: document))
        }
        let vocabulary = try await Vocabulary.standard.value

        self.modules = modules
        self.vocabulary = vocabulary
        self.compiled = vocabulary.laid.compiled
            + (try await Builder().compile(modules, against: vocabulary.laid))
    }

    // MARK: - Public
    // How long compiling these documents and then linking them takes.
    func build() async throws -> Duration {
        let builder = Builder()

        return try await Stopwatch().elapsed {
            _ = try builder.link(
                vocabulary.laid.compiled + (try await builder.compile(modules, against: vocabulary.laid)),
                supplying: vocabulary.brought
            )
        }
    }

    // How long compiling every document together takes.
    func compile() async throws -> Duration {
        let builder = Builder()

        return try await Stopwatch().elapsed {
            _ = try await builder.compile(modules, against: vocabulary.laid)
        }
    }

    // How long the same documents cost compiled one at a time, added up.
    func alone() async throws -> Duration {
        let builder = Builder()

        return try await Stopwatch().elapsed {
            for module in modules {
                _ = try await builder.compile([module], against: vocabulary.laid)
            }
        }
    }

    // How long laying the compiled documents down together takes.
    func link() throws -> Duration {
        try Stopwatch().elapsed {
            _ = try Builder().link(compiled, supplying: vocabulary.brought)
        }
    }

    // MARK: - Private
    private static func name(_ number: Int) throws -> Name { try Name("Fanout.procedure\(number)") }

    private static func type(_ number: Int) throws -> Name { try Name("Fanout.Type\(number)") }

    // One document: a type for each procedure it holds, and each procedure standing on
    // its own type and answering what it was sent. It imports nothing, which is
    // what leaves its compile a question about itself.
    private static func document(_ held: Range<Int>) throws -> Module {
        var types: [Name: TypeExpression] = [:]
        var procedures: [Name: Procedure] = [:]

        for number in held {
            types[try type(number)] = .record(["value": .int])
            procedures[try name(number)] = try procedure(number)
        }

        return try Module(imports: [], types: types, procedures: procedures)
    }

    private static func procedure(_ number: Int) throws -> Procedure {
        let held = Warp.Expression.reference([.key("held"), .key("value")])

        return Procedure(
            signature: Signature(parameters: [Parameter(name: "value", type: .int)], returns: .int),
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .cast(
                        .record(["value": .reference([.key("value")])]),
                        as: .named(try type(number)),
                        optional: false
                    )
                )
            ],
            result: held
        )
    }
}
