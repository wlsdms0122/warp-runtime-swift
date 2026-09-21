//
//  Image.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What a link produces and a run reads: every declaration lowered into one
// table, the row a run starts from, the types the link declared, and what
// each document's variables start out holding. A closure literal's row is
// held by the code that makes the closure. Only
// `Builder` makes one, so holding a value of this type is the evidence that
// linking happened. An image is made per link and not kept: its rows mean
// something within that link alone.
public struct Image: Sendable {
    // MARK: - Property
    public let linked: [Linked]

    // Every declared spelling a caller may name, by row.
    public let rows: [Name: Int]

    // The spellings only a private declaration wears: declared, and by
    // nothing outside its document. Read only after a spelling is not a row,
    // to say which refusal it is.
    let concealed: Set<Name>

    // Every type the linked modules declared. A named type survives into the
    // run as a row of the table's lowering rather than being expanded at
    // link, so the run needs the table that answers it.
    public let types: TypeTable

    var loweredTypes: LoweredTypeTable { types.loweredTypes }

    // What each document's variables start a run holding, by the document's
    // position in the link, in the order the layouts read them. A run makes
    // one box per variable from these, in this order.
    public let variables: [[(name: Name, value: Value)]]

    // What a closure each document writes is spelled with, by origin.
    let naming: [Closure.Document]

    // MARK: - Initializer
    init(
        linked: [Linked],
        rows: [Name: Int],
        concealed: Set<Name>,
        types: TypeTable,
        variables: [[(name: Name, value: Value)]],
        naming: [Closure.Document]
    ) {
        self.linked = linked
        self.rows = rows
        self.concealed = concealed
        self.types = types
        self.variables = variables
        self.naming = naming
    }

    // MARK: - Public
    // Which declarations a run starting from one can reach, by declared
    // spelling. Transitive, read off the rows' code; what one row reaches is
    // `Linked.reaches`. A fact of the link for whoever asks it; the run reads
    // rows by number and never asks. Nothing under a spelling no row wears.
    public func reached(from entry: Name) throws -> Set<Name> {
        guard let start = rows[entry] else { return [] }

        let walked = try linked.reached(from: start, starting: variables, in: [])

        return Set(rows.lazy.filter { row in walked.contains(row.value) }.map(\.key))
    }

    // The row under a declared spelling.
    public subscript(declared: Name) -> Linked? {
        rows[declared].map { row in linked[row] }
    }

    // A value settled by a type this link declared: the declaration gives the
    // layout and holds every field to its type, so what comes back is what a
    // slot of that type holds.
    public func settling(_ value: Value, as declared: Name) throws -> Value {
        guard let row = loweredTypes.row(named: declared) else {
            throw ValueRefused("no type named '\(declared)' is declared here")
        }

        return try LoweredType.named(row).settling(value, at: declared.spelling, in: loweredTypes, assuming: [])
    }

    // MARK: - Private
}
