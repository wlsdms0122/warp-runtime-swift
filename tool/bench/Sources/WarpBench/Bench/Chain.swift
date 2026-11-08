//
//  Chain.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Warp
import WarpStandard
import WarpSyntax

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
    // One document: a type for each procedure it holds, and each procedure standing on
    // its own type and handing what it was sent to the procedure in front of it.
    // A document holding a run sends exactly one procedure it does not declare,
    // however many documents the procedures were dealt into.
    private static func document(_ held: Range<Int>) throws -> Module {
        let sent = held.lowerBound > 0 ? ["(import Chain.step\(held.lowerBound - 1))"] : []
        let text = (["(warp 1)"] + sent + held.map(declarations)).joined(separator: "\n")

        return try Loader().load(try TextEncoding().value(from: text))
    }

    private static func declarations(_ number: Int) -> String {
        let returned = number > 0 ? "(call Chain.step\(number - 1) (path held (field value)))" : "(path held (field value))"

        return """
            (struct Chain.Step\(number)
              (field value Int))
            (procedure Chain.step\(number)
              (parameter value (type Int))
              (returns Int)
              (failing cast_refused)
              (body
                (let held (as (struct (field value value)) Chain.Step\(number)))
                (return \(returned))))
            """
    }
}
