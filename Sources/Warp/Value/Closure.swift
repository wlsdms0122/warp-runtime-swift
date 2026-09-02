//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// A procedure together with the scope it was written in. This is what a
// procedure literal answers with, and it is the only shape a value can have that
// can be called.
//
// The captured scope is what makes it a closure rather than a body: a literal
// written inside a loop round sees that round's names forever after, and calling
// it later does not put it back where the caller stands. Scope is lexical.
//
// A declared procedure and an anonymous one are the same `Procedure`. What
// separates them is only whether a module declares it under a name, which is a
// fact about the module rather than about the thing declared.
public struct Closure: Sendable {
    // MARK: - Property
    public let procedure: Procedure
    public let captured: Scope

    // What the link derived about the literal's text, carried with the value so
    // a slot the link could not see — one reached through `any`, or through a
    // field no declaration named — still asks it. A closure a caller assembles
    // claims nothing, and claims nothing is what fits only a slot that asks
    // nothing.
    public let purity: Purity
    public let isolation: Isolation

    // MARK: - Initializer
    public init(
        procedure: Procedure,
        captured: Scope,
        purity: Purity = .unstated,
        isolation: Isolation = .unstated
    ) {
        self.procedure = procedure
        self.captured = captured
        self.purity = purity
        self.isolation = isolation
    }

    // MARK: - Public
    // Whether this may run beside another body: it was derived isolated, or it
    // is pure, since what runs nothing touches nothing.
    public var runsBeside: Bool {
        isolation == .isolated || purity == .pure
    }

    // MARK: - Private
}
