//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// One parameter of a declaration: the name its body reads it by, what it
// takes, and what the boundary asks beyond the type. The name is the
// declaration's; a procedure type carries none.
public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    public let name: Name

    // What this takes, or nil where nothing was declared. `Any` is a claim that
    // any type is welcome; nil is the absence of a claim. Neither is checked,
    // and keeping them apart is what lets the ones written on purpose be told
    // from the ones nobody got around to.
    public let type: TypeExpression?
    public let candidates: [String]?
    public let description: String?

    // What this reads as where a type is needed regardless. An undeclared
    // parameter accepts what it is handed, which is what `Any` says.
    public var declared: TypeExpression { type ?? .any }

    // MARK: - Initializer
    public init(
        name: Name,
        type: TypeExpression? = nil,
        candidates: [String]? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.candidates = candidates
        self.description = description
    }

    // MARK: - Public
    // A host's door onto the boundary a run keeps: this parameter lowered
    // into the slot the run reads, and the value settled by it.
    public func checking(
        _ value: Value,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(in: types.loweredTypes).checking(value, at: "input '\(name)'", in: types.loweredTypes)
    }

    // MARK: - Private
}
