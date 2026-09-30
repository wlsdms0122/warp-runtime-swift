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
// lowered type table, so it stands where a table does. A document has none, and
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
        case body(LoweredBody, Frame)

        // The spellings the procedure this row was compiled against said it
        // sends, in the places it names them at. What it reads is the
        // declaration's parameters in order, which the row's own slots
        // stand in, so only the sends are written down.
        case native(sending: [Native.Send])
    }

    // MARK: - Property
    let label: Name
    let signature: Signature

    // Who may name this row. A lifted closure is its document's and nothing
    // names it, so it is private.
    let access: Access

    let constness: Constness
    let isolation: Isolation
    let failing: Failing

    // The sends this row's procedure declared, in the places the procedure names them
    // at: the row each reaches, numbered by the document, and where what it
    // hands over stands. Empty for a body, whose sends are calls its own code
    // carries.
    let sends: [Sent]

    let implementation: Implementation

    // MARK: - Initializer
    // Each part stated. Reached through the two doors below: one judges parts
    // read apart, and one takes a row the link built, whose frame stood up
    // beside its body.
    private init(
        label: Name,
        signature: Signature,
        access: Access,
        constness: Constness,
        isolation: Isolation,
        failing: Failing,
        sends: [Sent],
        implementation: Implementation
    ) {
        self.label = label
        self.signature = signature
        self.access = access
        self.constness = constness
        self.isolation = isolation
        self.failing = failing
        self.sends = sends
        self.implementation = implementation
    }

    // The same, where the parts were read apart and what has to be true is how
    // the body, its frame and the declaration stand to each other.
    init(
        label: Name,
        signature: Signature,
        access: Access,
        constness: Constness,
        isolation: Isolation,
        failing: Failing,
        sends: [Sent],
        judging implementation: Implementation
    ) throws {
        try Self.judge(implementation, against: signature)

        self.init(
            label: label,
            signature: signature,
            access: access,
            constness: constness,
            isolation: isolation,
            failing: failing,
            sends: sends,
            implementation: implementation
        )
    }

    // What of a row its document settled. What is left behind is a reading of
    // this against a table, which any table gives again. The link stood the
    // frame up beside the body it lowered, so what a reading of an object has
    // to judge, a build already holds, and a debug build says so.
    init(_ row: Linked) {
        let implementation: Implementation

        switch row.implementation {
        case let .body(body, frame):
            implementation = .body(body, frame)

        case let .native(procedure):
            implementation = .native(sending: procedure.sending)
        }

        do {
            try Self.judge(implementation, against: row.signature)
        } catch {
            assertionFailure("the link stands a body up beside a frame that fits it: \(error)")
        }

        self.label = row.label
        self.signature = row.signature
        self.access = row.access
        self.constness = row.constness
        self.isolation = row.isolation
        self.failing = row.failing
        self.sends = row.sends
        self.implementation = implementation
    }

    // MARK: - Public
    // What the body stands on, judged against the frame it stands in and
    // against the rows beside it. One walk answers all of them, so the walk is
    // here rather than split between this row and the list that holds it, and
    // what the list alone knows is handed in.
    //
    // A frame is reached by position everywhere a run touches it, and so are
    // the boxes a document holds and the frames its closures stand in. A list
    // written short is an array read past its end rather than a row that
    // answers wrongly.
    func judge(
        standingIn frames: (Int) -> Frame?,
        reaching given: (Int) -> Int?,
        holding variables: Int
    ) throws {
        guard case let .body(body, frame) = implementation else { return }

        let standing = body.standing

        guard standing.slots.allSatisfy({ slot in slot < frame.size }),
            standing.extents.allSatisfy({ run in run.upperBound <= frame.size })
        else {
            throw ObjectRefused(
                "a body stands on a slot its frame of \(frame.size) does not hold"
            )
        }

        guard frame.variables.allSatisfy({ variable, _ in variable < variables }) else {
            throw ObjectRefused(
                "a body stands on a variable past the \(variables) its document holds"
            )
        }

        // What a call hands over fills the slots the row it reaches declares,
        // and a run writes them by position. Answered where the row is this
        // document's own; a row another document holds is the link's answer
        // and is asked there, as is a number this document never gave.
        for call in standing.calls {
            guard let taking = given(call.number) else { continue }

            guard taking == call.arguments else {
                throw ObjectRefused(
                    "a call stands \(call.arguments) argument(s) where the"
                        + " \(taking) its callee declares stand"
                )
            }
        }

        // What a closure takes with it fills the slots its own frame is
        // filled at, since a run writes them by position.
        for closure in standing.closures {
            guard let stands = frames(closure.number) else { continue }

            guard stands.fills(closure.inner) else {
                throw ObjectRefused(
                    "a closure takes something into slots other than the ones its own frame is filled at"
                )
            }
        }
    }

    // This declaration as a row of the table given, standing at the position
    // its block landed at. Compiling and linking both call this, each against
    // its own table, which is what makes the two readings one.
    //
    // A native row is joined to the code the host brought under its spelling,
    // which is the one thing a document settled that the document does not
    // hold.
    func linked(
        in table: LoweredTypeTable,
        of origin: Int,
        closure: (by: Closure.Declaration, nth: Int)?,
        supplied: Supplying,
        at document: Place.Document
    ) throws -> Linked {
        try linked(in: table, of: origin, closure: closure, supplied: supplied, at: document, standing: false)
    }

    // The same, where a row the supply brings no code for stands as the
    // refusal it earns instead of stopping here. A compile runs a procedure only
    // where it folds a constant through it, so what it never folds it never
    // needed; a link states what the whole run may call, and asks for all of
    // it.
    func folding(
        in table: LoweredTypeTable,
        of origin: Int,
        closure: (by: Closure.Declaration, nth: Int)?,
        supplied: Supplying,
        at document: Place.Document
    ) throws -> Linked {
        try linked(in: table, of: origin, closure: closure, supplied: supplied, at: document, standing: true)
    }

    // MARK: - Private
    // How a body, its frame and the declaration stand to each other. A frame
    // is reached by position everywhere a run touches it, so a list written
    // short is an array read past its end rather than a row that answers
    // wrongly.
    private static func judge(
        _ implementation: Implementation,
        against signature: Signature
    ) throws {
        guard case let .body(_, frame) = implementation else { return }

        guard frame.names.count == frame.size else {
            throw ObjectRefused(
                "a frame of \(frame.size) names \(frame.names.count) slot(s)"
            )
        }

        guard frame.captures.allSatisfy({ slot in slot >= 0 && slot < frame.size }) else {
            throw ObjectRefused("a frame is filled from a closure's cells at a slot it has not")
        }

        guard frame.parameters.count == signature.names.count else {
            throw ObjectRefused(
                "a frame stands \(frame.parameters.count) of the"
                    + " \(signature.names.count) its declaration takes"
            )
        }

        guard frame.parameters.allSatisfy({ slot in slot < frame.size }),
              frame.variables.allSatisfy({ _, slot in slot < frame.size })
        else {
            throw ObjectRefused(
                "a frame of \(frame.size) stands a parameter or a variable past its end"
            )
        }
    }
    private func linked(
        in table: LoweredTypeTable,
        of origin: Int,
        closure: (by: Closure.Declaration, nth: Int)?,
        supplied: Supplying,
        at document: Place.Document,
        standing: Bool
    ) throws -> Linked {
        switch implementation {
        case let .body(body, frame):
            return row(.body(body, frame), of: origin, closure: closure, foldable: true, in: table)

        case let .native(sending):
            guard let brought = supplied[label, at: document] else {
                guard standing else { throw self.brought(nothing: document) }

                // The door it answers through is the row's own: a native
                // query is what a compile settled as const, and a stand-in on
                // the other door would be read the wrong way by a run.
                return row(
                    .native(constness == .const ? .query(UnbroughtQuery(label)) : .effect(UnbroughtEffect(label))),
                    of: origin,
                    foldable: true,
                    in: table
                )
            }

            // A procedure declares its own constness, isolation, failing and the
            // places it sends at, and the module bringing it declares what it
            // takes and answers. This row carries what the procedure a compile was
            // handed declared, so a host bringing a procedure saying something else
            // brings a row standing on claims nothing here makes.
            guard
                constness == brought.native.constness,
                isolation == brought.native.isolation,
                failing == brought.native.failing,
                signature == brought.signature,
                sending == brought.sending
            else {
                throw self.brought(otherwise: brought, sending: sending, in: document)
            }

            return row(.native(brought.native), of: origin, foldable: brought.builtin, in: table)
        }
    }

    private func row(
        _ implementation: Linked.Implementation,
        of origin: Int,
        closure: (by: Closure.Declaration, nth: Int)? = nil,
        foldable: Bool,
        in table: LoweredTypeTable
    ) -> Linked {
        Linked(
            label: label,
            origin: origin,
            signature: signature,
            access: access,
            constness: constness,
            isolation: isolation,
            failing: failing,
            implementation: implementation,
            foldable: foldable,
            sends: sends,
            closure: closure,
            in: table
        )
    }

    // A row whose document left it to native code, and a link that brought
    // none. It is refused here rather than where the call is made: what a
    // caller brings is a statement about the whole run.
    private func brought(nothing document: Place.Document) -> BuildError {
        BuildError(
            "'\(label)' is implemented in native code and this link was handed none."
                + " What a caller brings is declared where the run is assembled",
            at: .procedure(label.spelling, in: document)
        )
    }

    private func brought(
        otherwise brought: Supplying.Brought,
        sending: [Native.Send],
        in document: Place.Document
    ) -> BuildError {
        let differing = [
            constness == brought.native.constness ? nil : "constness",
            isolation == brought.native.isolation ? nil : "isolation",
            failing == brought.native.failing ? nil : "failing",
            signature == brought.signature ? nil : "declaration",
            sending == brought.sending ? nil : "sends"
        ].compactMap { axis in axis }

        return BuildError(
            "'\(label)' stands on what the procedure a compile was handed said about its"
                + " \(differing.joined(separator: ", ")), and the procedure brought under"
                + " that spelling says otherwise",
            at: .procedure(label.spelling, in: document)
        )
    }
}
