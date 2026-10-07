//
//  Chain.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Warp
import WarpStandard

// A chain of procedures, each calling the procedure in front of it, dealt into a given
// number of documents and built as many times as asked.
//
// The procedures and the documents are the two counts a build carries, and
// they move apart here so that a figure says which one it pays for. Dealt into
// fewer documents, the same procedures leave compile the same bodies to lower
// and the link the same names to place.
//
// Dealt one to a document, the last document depends on every document in
// front of it, so the dependency closures sum to the square of the count.
// `Fanout`'s procedures share nothing and keep them at one.
//
// The standard vocabulary is in every build here, the way every other
// workload builds against it, so the counts say where the chain's own
// procedures overtake what the vocabulary always costs.
struct Chain {
    // MARK: - Property
    private let modules: [Module]

    // MARK: - Initializer
    init(_ dealing: Dealing) throws {
        self.modules = try (0 ..< dealing.documents).map { document in
            try Self.document(dealing.held(by: document))
        } + Module.standard
    }

    // MARK: - Public
    // How long one build of these modules takes.
    func build() async throws -> Duration {
        try await Stopwatch().elapsed { _ = try await Builder().build(modules) }
    }

    // MARK: - Private
    private static func step(_ number: Int) throws -> Name { try Name("Chain.step\(number)") }

    private static func type(_ number: Int) throws -> Name { try Name("Chain.Step\(number)") }

    // One document: a type for each procedure it holds, and each procedure standing on
    // its own type and handing what it was sent to the procedure in front of it.
    // A document holding a run sends exactly one procedure it does not declare,
    // however many documents the procedures were dealt into.
    private static func document(_ held: Range<Int>) throws -> Module {
        let sent = try held.lowerBound > 0 ? [step(held.lowerBound - 1)] : []
        var types: [Name: TypeExpression] = [:]
        var procedures: [Name: Procedure] = [:]

        for number in held {
            types[try type(number)] = .record(["value": .int])
            procedures[try step(number)] = try procedure(number)
        }

        return try Module(imports: Set(sent), types: types, procedures: procedures)
    }

    private static func procedure(_ number: Int) throws -> Procedure {
        let ahead = number > 0 ? try step(number - 1) : nil
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
            result: ahead.map { name in .call(Call(selector: name, arguments: [held])) } ?? held
        )
    }
}
