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
        let parameters = signature.parameters
            .sorted { left, right in left.key < right.key }
            .map { entry in (name: entry.key, parameter: entry.value) }

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
    // Whether this row is a written body.
    public var isWritten: Bool {
        if case .body = implementation { return true }

        return false
    }

    // MARK: - Private
}
