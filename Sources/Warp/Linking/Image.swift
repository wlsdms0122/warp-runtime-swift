//
//  Image.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What a link produces and a run reads: every declaration lowered into one
// table, the row a run starts from, the shapes the link declared, and what
// each document's variables start out holding. A closure literal's row is
// held by the code that makes the closure. Only
// `Linker` makes one, so holding a value of this type is the evidence that
// linking happened. An image is made per link and not kept: its rows mean
// something within that link alone.
public struct Image: Sendable {
    // MARK: - Property
    public let linked: [Linked]

    // The row a run starts from.
    public let start: Int

    // Every declared spelling, by row.
    public let rows: [String: Int]

    // Which declarations a run from the entry can reach, by declared
    // spelling. Transitive: a declaration reached only through another is
    // in here too. A fact of the link for whoever asks it; the run reads
    // rows by number and never asks.
    public let reached: Set<String>

    // Every shape the linked modules declared. A named type survives into the
    // run rather than being expanded at link, so the run needs the table that
    // answers it.
    public let types: TypeTable

    // What each document's variables start a run holding, by the document's
    // position in the link, in the order the layouts read them. A run makes
    // one box per variable from these, in this order.
    public let variables: [Int: [(name: String, value: Value)]]

    // MARK: - Initializer
    init(
        linked: [Linked],
        start: Int,
        rows: [String: Int],
        reached: Set<String>,
        types: TypeTable,
        variables: [Int: [(name: String, value: Value)]]
    ) {
        self.linked = linked
        self.start = start
        self.rows = rows
        self.reached = reached
        self.types = types
        self.variables = variables
    }

    // MARK: - Public
    public var entry: Linked { linked[start] }

    // The row under a declared spelling.
    public subscript(declared: String) -> Linked? {
        rows[declared].map { row in linked[row] }
    }

    // MARK: - Private
}
