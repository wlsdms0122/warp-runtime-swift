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
// until the link reading the object answers it.
public struct Closure: Sendable {
    // The declaration, constant or variable that wrote a closure, in the
    // document it stands in. A constant's spelling is its document's own, so
    // the document is part of the name.
    struct Writer: Hashable, Sendable {
        let document: Place.Document
        let name: Name
    }

    // MARK: - Property
    let writer: Writer
    let nth: Int

    // Where the writer stood in the link the run that made this value ran
    // in, by position. Two documents nobody wrote down are told apart by
    // nothing else. Nil once the value has been written down, since an
    // object spells no position, and what it spells is a document that was
    // written down.
    let origin: Int?

    public let linked: Linked?
    let captured: [(slot: Int, cell: Cell)]

    // Whether this may run beside another body. Constness does not answer it: a
    // const body can still call a native procedure that holds state, and that procedure
    // is what two of these would meet in.
    public var runsBeside: Bool {
        linked?.isolation == .isolated
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
    init(writer: Writer, nth: Int, origin: Int?, linked: Linked?, captured: [(slot: Int, cell: Cell)]) {
        self.writer = writer
        self.nth = nth
        self.origin = origin
        self.linked = linked
        self.captured = captured
    }

    // MARK: - Public
    // The same closure as a link reads it: the body standing in that link's
    // tables.
    func standing(as linked: Linked) -> Closure {
        Closure(writer: writer, nth: nth, origin: origin, linked: linked, captured: captured)
    }

    // The same closure holding something else.
    func holding(_ captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(writer: writer, nth: nth, origin: origin, linked: linked, captured: captured)
    }

    // MARK: - Private
}
