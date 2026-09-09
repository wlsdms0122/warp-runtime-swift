//
//  Judged.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// A declaration, or a closure literal, as its own document settles it. What
// compiling answers and what a link is handed.
//
// What a row's slots and answer lower to is this signature read against a
// shape table, so it stands where a table does. A document has none, and
// that is the whole difference between this and a row.
//
// Which document a row came out of is not here either: the block it stands in
// says it. A link lays the blocks down and stamps each row with where its
// block landed, so a document reused in another link carries nothing it would
// have to be corrected about.
struct Judged: Sendable {
    // MARK: - Property
    let label: Name
    let signature: Signature
    let purity: Purity
    let isolation: Isolation
    let failing: Failing

    // The rows this row's word sends, in the places the word names them at,
    // numbered by the document. Empty for a body, whose sends are calls its
    // own code carries.
    let sends: [Int]

    let implementation: Linked.Implementation

    // MARK: - Initializer
    // What of a row its document settled. What is left behind is a reading of
    // this against a table, which any table gives again.
    init(_ row: Linked) {
        self.label = row.label
        self.signature = row.signature
        self.purity = row.purity
        self.isolation = row.isolation
        self.failing = row.failing
        self.sends = row.sends
        self.implementation = row.implementation
    }

    // MARK: - Public
    // This declaration as a row of the table given, standing at the position
    // its block landed at. Compiling and linking both call this, each against
    // its own table, which is what makes the two readings one.
    func lowered(in table: ShapeTable, of origin: Int) -> Linked {
        Linked(
            label: label,
            origin: origin,
            signature: signature,
            purity: purity,
            isolation: isolation,
            failing: failing,
            implementation: implementation,
            sends: sends,
            in: table
        )
    }

    // MARK: - Private
}
