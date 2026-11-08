//
//  Procedure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A declaration: what it is sent, what it returns, and how it does that.
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
    public let signature: Signature
    package let implementation: Implementation

    // Who may name this declaration: its own document, the link, or the host
    // as well. `internal` where the declaration said nothing.
    public let access: Access

    package var body: Body { implementation.body ?? [] }

    // MARK: - Initializer
    // A procedure the host implements, which is how a host lends one.
    public init(
        access: Access = .internal,
        signature: Signature = Signature(),
        implementation native: Native
    ) {
        switch native {
        case let .query(query):
            self.init(access, signature, Implementation.query(query))

        case let .effect(effect):
            self.init(access, signature, Implementation.effect(effect))
        }
    }

    // A procedure written in the language, the one a document spells.
    package init(
        access: Access = .internal,
        signature: Signature = Signature(),
        body: Body
    ) {
        self.init(access, signature, .body(body))
    }

    private init(_ access: Access, _ signature: Signature, _ implementation: Implementation) {
        self.access = access
        self.signature = signature
        self.implementation = implementation
    }

    // MARK: - Public
    // The same declaration under another signature: a member's signature
    // read under its head's bounds.
    func with(signature: Signature) -> Procedure {
        Procedure(access, signature, implementation)
    }

    public func with(access: Access) -> Procedure {
        Procedure(access, signature, implementation)
    }

    // MARK: - Private
}
