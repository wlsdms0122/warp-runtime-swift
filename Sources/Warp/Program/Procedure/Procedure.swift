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

    public var block: Block? { implementation.block }
    public var body: Body { block?.body ?? [] }
    public var result: Expression? { block?.result }

    // MARK: - Initializer
    public init(
        description: String? = nil,
        access: Access = .internal,
        signature: Signature = Signature(),
        implementation: Implementation
    ) {
        self.description = description
        self.access = access
        self.signature = signature
        self.implementation = implementation
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
    // The same declaration under another signature: what a closure's
    // signature reads as once it is completed or bounded.
    public func with(signature: Signature) -> Procedure {
        Procedure(
            description: description,
            access: access,
            signature: signature,
            implementation: implementation
        )
    }

    public func with(access: Access) -> Procedure {
        Procedure(
            description: description,
            access: access,
            signature: signature,
            implementation: implementation
        )
    }

    // MARK: - Private
}
