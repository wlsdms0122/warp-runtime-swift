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
    // How a declaration answers, as its own document settled it. A written
    // body is lowered code with its frame layout; a native is this row's
    // spelling and the claims standing beside it, and the code a run calls
    // comes from the host.
    enum Implementation: Sendable {
        case body(Body, Frame)
        case native
    }

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

    let implementation: Implementation

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

        switch row.implementation {
        case let .body(body, frame):
            self.implementation = .body(body, frame)

        case .query, .effect:
            self.implementation = .native
        }
    }

    // MARK: - Public
    // This declaration as a row of the table given, standing at the position
    // its block landed at. Compiling and linking both call this, each against
    // its own table, which is what makes the two readings one.
    //
    // A native row is joined to the code the host brought under its spelling,
    // which is the one thing a document settled that the document does not
    // hold.
    func lowered(
        in table: ShapeTable,
        of origin: Int,
        supplied: Supplying,
        at document: Place.Document
    ) throws -> Linked {
        let implementation: Linked.Implementation

        switch self.implementation {
        case let .body(body, frame):
            implementation = .body(body, frame)

        case .native:
            guard let word = supplied[label] else { throw brought(nothing: document) }

            // A word declares its own purity, isolation and failing, and this
            // row carries what the word a compile was handed declared. A host
            // bringing a word saying something else brings a row judged
            // against claims nothing in this link makes.
            guard purity == word.purity, isolation == word.isolation, failing == word.failing else {
                throw brought(otherwise: word, in: document)
            }

            switch word {
            case let .query(query):
                implementation = .query(query)

            case let .effect(effect):
                implementation = .effect(effect)
            }
        }

        return Linked(
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
    // A row whose document left it to native code, and a link that brought
    // none. It is refused here rather than where the call is made: what a
    // caller brings is a statement about the whole run.
    private func brought(nothing document: Place.Document) -> LinkError {
        LinkError(
            "'\(label)' is implemented in native code and this link was handed none."
                + " What a caller brings is declared where the run is assembled",
            at: .procedure(label.spelling, in: document)
        )
    }

    private func brought(otherwise word: Native, in document: Place.Document) -> LinkError {
        let differing = [
            purity == word.purity ? nil : "purity",
            isolation == word.isolation ? nil : "isolation",
            failing == word.failing ? nil : "failing"
        ].compactMap { axis in axis }

        return LinkError(
            "'\(label)' stands on what the word a compile was handed said about its"
                + " \(differing.joined(separator: ", ")), and the word brought under"
                + " that spelling says otherwise",
            at: .procedure(label.spelling, in: document)
        )
    }
}
