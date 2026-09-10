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

        // What the word this row was compiled against declared beyond what
        // the row already says: the names it reads its arguments under and
        // the spellings it sends, both in the places it names them at. A row
        // stands on those places, so a word brought later that names others
        // is a different word under one spelling.
        case native(reading: [Name], sending: [Name])
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

        case let .query(query):
            self.implementation = Self.native(.query(query))

        case let .effect(effect):
            self.implementation = Self.native(.effect(effect))
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

        case let .native(reading, sending):
            guard let brought = supplied[label] else { throw self.brought(nothing: document) }

            // A word declares its own purity, isolation, failing, and the
            // places it reads and sends at. This row carries what the word a
            // compile was handed declared, so a host bringing a word saying
            // something else brings a row standing on claims nothing in this
            // link makes.
            guard
                purity == brought.word.purity,
                isolation == brought.word.isolation,
                failing == brought.word.failing,
                reading == brought.reading,
                sending == brought.sending
            else {
                throw self.brought(
                    otherwise: brought,
                    reading: reading,
                    sending: sending,
                    in: document
                )
            }

            switch brought.word {
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
    // What this row was compiled against, where it was left to native code.
    // A body reads and sends nothing a word declared, so it answers with
    // neither.
    private static func native(_ word: Native) -> Implementation {
        .native(reading: word.reading, sending: word.sending)
    }

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

    private func brought(
        otherwise brought: Supplying.Brought,
        reading: [Name],
        sending: [Name],
        in document: Place.Document
    ) -> LinkError {
        let differing = [
            purity == brought.word.purity ? nil : "purity",
            isolation == brought.word.isolation ? nil : "isolation",
            failing == brought.word.failing ? nil : "failing",
            reading == brought.reading ? nil : "parameters",
            sending == brought.sending ? nil : "sends"
        ].compactMap { axis in axis }

        return LinkError(
            "'\(label)' stands on what the word a compile was handed said about its"
                + " \(differing.joined(separator: ", ")), and the word brought under"
                + " that spelling says otherwise",
            at: .procedure(label.spelling, in: document)
        )
    }
}
