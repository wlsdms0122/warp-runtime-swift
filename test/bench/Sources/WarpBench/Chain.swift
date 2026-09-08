//
//  Chain.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Warp
import WarpStandard

// A world of documents where each one calls the one before it, linked as many
// times as asked.
//
// A chain rather than a set of documents that ignore each other: the last
// document here depends on every document in front of it, so the dependency
// closures sum to the square of the count while a set that shares nothing keeps
// them at one. The count is read against whichever of those a link is paying.
//
// The standard vocabulary is linked in the way every other workload links it.
// A document that arrives alone still pays for it, so the count says when a
// world's own documents overtake what one always costs.
struct Chain {
    // MARK: - Property
    let count: Int

    private let world: [Module]
    private let entry: Name

    // MARK: - Initializer
    init(of count: Int) throws {
        self.count = count
        self.entry = try Self.step(count - 1)
        self.world = try (0 ..< count).map(Self.document(at:)) + Module.standard
    }

    // MARK: - Public
    // Seconds one link of this world takes.
    func link() throws -> Duration {
        let clock = ContinuousClock()
        let started = clock.now

        _ = try Linker().link(world, entry: entry)

        return clock.now - started
    }

    // MARK: - Private
    private static func step(_ number: Int) throws -> Name { try Name("chain.step\(number)") }

    private static func shape(_ number: Int) throws -> Name { try Name("chain.Step\(number)") }

    // One document: a type of its own, and a word that stands on that type and
    // hands what it was sent to the word in front of it. Both numbering axes
    // are on the body, so a document costs a link what a written one costs.
    private static func document(at number: Int) throws -> Module {
        let ahead = number > 0 ? try step(number - 1) : nil

        return try Module(
            imports: ahead.map { name in [name] } ?? [],
            types: [try shape(number): .record(["value": .int])],
            procedures: [
                try step(number): Procedure(
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
                    result: ahead.map { name in
                        .call(Call(selector: name, arguments: ["value": .reference([.key("held"), .key("value")])]))
                    } ?? .reference([.key("held"), .key("value")])
                )
            ]
        )
    }
}
