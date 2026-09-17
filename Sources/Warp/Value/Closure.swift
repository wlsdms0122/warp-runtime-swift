//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A procedure as a value: which closure it is, the row a link answered for
// it, and the cells it took from the frame it was written in, each with the
// slot it fills in the closure's own frame. A value cell was copied; a hold
// shares its box.
//
// Which closure it is, is spelled by its writer and which of the writer's it
// is: what an object writes a closure down as, and what a link answers a row
// for. A closure a fold settled into an object stands by that spelling alone
// until the link reading the object answers it. No position in any link
// rides along: a compiled document is laid into whatever link a caller makes
// of it, in whatever order, and a spelling is what survives that.
public struct Closure: Sendable {
    // The declaration, constant or variable that wrote a closure, in the
    // document it stands in. A constant's spelling is its document's own, so
    // the document is part of the name.
    struct Writer: Hashable, Sendable {
        let document: Document
        let name: Name
    }

    // How a writer's document is told from another: by the text it was read
    // from where it was written down, and by the compile that made it
    // otherwise. The second names nothing outside the link it was compiled
    // for, and an object spells only the first.
    enum Document: Hashable, Sendable {
        case written(Identity)
        case compiled(Compiled.Token)

        // The one rule: the text where there is one, the compile otherwise.
        init(identity: Identity?, token: Compiled.Token) {
            self = identity.map(Document.written) ?? .compiled(token)
        }
    }

    // MARK: - Property
    let writer: Writer
    let nth: Int

    let linked: Linked?
    let captured: [(slot: Int, cell: Cell)]

    // Whether this may run beside another body. Constness does not answer it: a
    // const body can still call a native procedure that holds state, and that procedure
    // is what two of these would meet in. Asked of the row the link answered,
    // so a closure no link answered is refused here rather than read as one
    // that may not.
    public func runsBeside() throws -> Bool {
        try answered().isolation == .isolated
    }

    // Whether a cell it took is a hold rather than a copy: a box of the
    // frame it was written in, shared with it.
    var tookAHold: Bool {
        captured.contains { _, cell in
            if case .hold = cell { return true }

            return false
        }
    }

    // MARK: - Initializer
    init(writer: Writer, nth: Int, linked: Linked?, captured: [(slot: Int, cell: Cell)]) {
        self.writer = writer
        self.nth = nth
        self.linked = linked
        self.captured = captured
    }

    // MARK: - Public
    // The row a link answered for this closure. A closure reaches a run only
    // through a link, so one without a row there is one no link read. A
    // settling reads the row for itself, since it refuses in its caller's
    // words.
    public func answered() throws -> Linked {
        guard let linked else { throw ExecutionError("a closure no link answered") }

        return linked
    }

    // The same closure as a link reads it: the body standing in that link's
    // tables.
    func standing(as linked: Linked) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured)
    }

    // The same closure holding something else.
    func holding(_ captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured)
    }

    // MARK: - Private
}
