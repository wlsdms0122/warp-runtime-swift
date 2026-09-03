//
//  Linked.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One row of the table a run reads: a declaration, or a closure literal, as
// the link left it. A written body is lowered code with its frame layout; a
// native answers as it is. A class, so a call reads its row without copying
// it and a closure value holds its own row.
public final class Linked: Sendable {
    enum Implementation: Sendable {
        case body(Body, Layout)
        case query(any Query)
        case effect(any Effect)
    }

    // MARK: - Property
    // The declared spelling, or the spelling of the declaration a closure was
    // written in. What a trace and a refusal call this row.
    public let label: String

    // Which document declared it, whose variables its body reads.
    public let origin: Int

    public let signature: Signature

    // The parameters in the order arguments stand in, with what settles them.
    public let parameters: [(name: String, parameter: Parameter)]

    // Where the receiver stands among them, for a declaration that takes one.
    public let receiverPosition: Int?

    public let purity: Purity
    public let isolation: Isolation

    let implementation: Implementation

    // MARK: - Initializer
    init(
        label: String,
        origin: Int,
        signature: Signature,
        purity: Purity,
        isolation: Isolation,
        implementation: Implementation
    ) {
        let parameters = signature.ordered

        self.label = label
        self.origin = origin
        self.signature = signature
        self.parameters = parameters
        self.receiverPosition = signature.receiver.flatMap { receiver in
            parameters.firstIndex { name, _ in name == receiver }
        }
        self.purity = purity
        self.isolation = isolation
        self.implementation = implementation
    }

    // MARK: - Public
    // A declaration's row before its body is lowered: a native answers as it
    // is, and a written body stands as the refusal it earns until then, so
    // nothing folds through a body half-made. Until it is lowered such a row
    // is not written, since what it holds is the refusal.
    static func standing(
        label: String,
        origin: Int,
        procedure: Procedure,
        pure: Bool,
        isolated: Bool
    ) -> Linked {
        let implementation: Implementation

        switch procedure.implementation {
        case .body:
            implementation = .query(UnsettledWord())

        case let .query(query):
            implementation = .query(query)

        case let .effect(effect):
            implementation = .effect(effect)
        }

        return Linked(
            label: label,
            origin: origin,
            signature: procedure.signature,
            purity: pure ? .pure : .unstated,
            isolation: isolated ? .isolated : .unstated,
            implementation: implementation
        )
    }

    // The receiver settled against the parameter at this row's receiver
    // position, or as it is where the row takes none.
    func settling(receiver value: Value, in types: TypeTable) throws -> Value {
        guard let position = receiverPosition else { return value }

        let declared = parameters[position]

        return try declared.parameter.checking(receiver: value, called: declared.name, in: types)
    }

    // Whether this row is a written body.
    public var isWritten: Bool {
        if case .body = implementation { return true }

        return false
    }

    // MARK: - Private
}
