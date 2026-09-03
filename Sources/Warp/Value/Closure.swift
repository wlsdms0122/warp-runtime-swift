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
    public let linked: Linked
    let captured: [(slot: Int, cell: Cell)]

    public var signature: Signature { linked.signature }

    // What the link derived about the literal's text, carried with the value so
    // a slot the link could not see, one reached through `any` or through a
    // field no declaration named, still asks it.
    public var purity: Purity { linked.purity }
    public var isolation: Isolation { linked.isolation }

    // MARK: - Initializer
    init(linked: Linked, captured: [(slot: Int, cell: Cell)]) {
        self.linked = linked
        self.captured = captured
    }

    // MARK: - Public
    func settling(returned value: Value) throws -> Value {
        try linked.settling(returned: value)
    }

    // Whether this may run beside another body: it was derived isolated, or it
    // is pure, since what runs nothing touches nothing.
    public var runsBeside: Bool {
        isolation == .isolated || purity == .pure
    }

    // MARK: - Private
}
