//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A procedure as a value: the row its body was lowered into, and the cells
// it took from the frame it was written in, each with the slot it fills in
// the closure's own frame. A value cell was copied; a hold shares its box.
public struct Closure: Sendable {
    // MARK: - Property
    // Which closure of which document this is, read the way the operation that
    // made it is read: the number is the document's own until a link answers
    // it, and the row once one has.
    let origin: Int
    let number: Int

    public let linked: Linked
    let captured: [(slot: Int, cell: Cell)]

    public var signature: Signature { linked.signature }

    // What the link derived about the literal's text, carried with the value so
    // a slot the link could not see, one reached through `any` or through a
    // field no declaration named, still asks it.
    public var constness: Constness { linked.constness }
    public var isolation: Isolation { linked.isolation }

    // MARK: - Initializer
    init(origin: Int, number: Int, linked: Linked, captured: [(slot: Int, cell: Cell)]) {
        self.origin = origin
        self.number = number
        self.linked = linked
        self.captured = captured
    }

    // The same closure as another link reads it: the row it turned out to be
    // there, the body standing in that link's tables, and what it captured
    // read the same way.
    func standing(at number: Int, as linked: Linked, holding captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(origin: origin, number: number, linked: linked, captured: captured)
    }

    // MARK: - Public
    func settling(returned value: Value) throws -> Value {
        try linked.settling(returned: value)
    }

    // Whether this may run beside another body. Constness does not answer it: a
    // const body can still call a native procedure that holds state, and that procedure
    // is what two of these would meet in.
    public var runsBeside: Bool {
        isolation == .isolated
    }

    // Whether a cell it took is a hold: a box of the frame it was written
    // in, shared with it rather than copied out of it.
    var capturesByReference: Bool {
        captured.contains { _, cell in
            if case .hold = cell { return true }

            return false
        }
    }

    // MARK: - Private
}
