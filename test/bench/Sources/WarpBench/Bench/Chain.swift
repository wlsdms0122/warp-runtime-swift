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
// number of documents and linked as many times as asked.
//
// The two counts are the two things a link is asked to carry, and they move
// apart here so that a figure can say which one it is paying for. Hold the
// procedures and deal them into fewer documents: a link has the same bodies to lower
// and the same names to place, and only the documents are fewer.
//
// A chain rather than `Fanout`'s procedures that ignore each other: dealt one to a
// document, the last document depends on every document in front of it, so the
// dependency closures sum to the square of the count while a set that shares
// nothing keeps them at one. That is the count a separate compile carries per
// document.
//
// The standard vocabulary is linked in the way every other workload links it.
// A document that arrives alone still pays for it, so the counts say when a
// world's own procedures overtake what one always costs.
struct Chain {
    // MARK: - Property
    private let world: [Module]

    // MARK: - Initializer
    init(_ dealing: Dealing) throws {
        self.world = try (0 ..< dealing.documents).map { document in
            try Self.document(dealing.held(by: document))
        } + Module.standard
    }

    // MARK: - Public
    // How long one build of this world takes.
    func build() async throws -> Duration {
        try await Stopwatch().elapsed { _ = try await Builder().build(world) }
    }

    // MARK: - Private
    private static func step(_ number: Int) throws -> Name { try Name("chain.step\(number)") }

    private static func type(_ number: Int) throws -> Name { try Name("chain.Step\(number)") }

    // One document: a type for each procedure it holds, and each procedure standing on
    // its own type and handing what it was sent to the procedure in front of it.
    // Holding a run leaves a document sending exactly one procedure it does not
    // declare, however many documents the procedures were dealt into.
    // What a procedure adds is a written body and the type it names, which is what a
    // link pays for a procedure somebody wrote.
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
