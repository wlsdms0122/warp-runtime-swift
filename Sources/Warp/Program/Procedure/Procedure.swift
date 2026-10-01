//
//  Procedure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A declaration: what it is sent, what it answers with, and how it does that.
//
// It has no name of its own. A procedure's name is the key it is declared under
// in its `Module`, the same way a symbol's name is not stored inside the
// function it names. A run names which one it starts from, so every
// declaration is equally a procedure and none of them is the procedure.
//
// A signature and an implementation, and nothing else. The implementation is a
// body of statements or native code, and that axis is the only thing separating
// one a document wrote from one the host installed. One name table, one lookup
// order.
public struct Procedure: Sendable {
    // MARK: - Property
    public let description: String?
    public let signature: Signature
    public let implementation: Implementation

    // Who may name this declaration: its own document, the link, or the host
    // as well. `internal` where the declaration said nothing.
    public let access: Access

    // What the build derived about this body, where the build has seen it: a
    // closure literal is rewritten by the build to carry them, and the closure
    // value made from it carries them on into a slot that asks. A procedure a
    // caller assembles claims nothing.
    public let constness: Constness
    public let isolation: Isolation
    public let failing: Failing

    public var block: Block? { implementation.block }
    public var body: Body { block?.body ?? [] }
    public var result: Expression? { block?.result }

    // MARK: - Initializer
    public init(
        description: String? = nil,
        access: Access = .internal,
        signature: Signature = Signature(),
        implementation: Implementation,
        constness: Constness = .unstated,
        isolation: Isolation = .unstated,
        failing: Failing = .unstated
    ) {
        self.description = description
        self.access = access
        self.signature = signature
        self.implementation = implementation
        self.constness = constness
        self.isolation = isolation
        self.failing = failing
    }

    // A procedure written in the language. The common case, and the one a
    // document can spell.
    public init(
        description: String? = nil,
        access: Access = .internal,
        signature: Signature = Signature(),
        body: Body,
        result: Expression? = nil
    ) {
        self.init(
            description: description,
            access: access,
            signature: signature,
            implementation: .body(Block(body: body, result: result))
        )
    }

    // MARK: - Public
    // The same declaration, named from another scope.
    public func with(signature: Signature) -> Procedure {
        Procedure(
            description: description,
            access: access,
            signature: signature,
            implementation: implementation,
            constness: constness,
            isolation: isolation,
            failing: failing
        )
    }

    public func with(access: Access) -> Procedure {
        Procedure(
            description: description,
            access: access,
            signature: signature,
            implementation: implementation,
            constness: constness,
            isolation: isolation,
            failing: failing
        )
    }

    // MARK: - Private
}
