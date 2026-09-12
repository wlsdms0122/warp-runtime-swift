//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    // What this takes, or nil where nothing was declared. `any` is a claim that
    // any type is welcome; nil is the absence of a claim. Neither is checked,
    // and keeping them apart is what lets the ones written on purpose be told
    // from the ones nobody got around to.
    public let type: TypeExpression?
    public let candidates: [String]?
    public let `default`: Value?
    public let description: String?

    // Whether a call must write this argument: the type's one answer, for
    // the call check, the boundary and path reachability alike.
    public func mustBeGiven(in types: TypeTable) -> Bool {
        declared.lowered(in: types.loweredTypes).mustBeGiven(default: `default`, in: types.loweredTypes)
    }

    // What this reads as where a type is needed regardless. An undeclared
    // parameter accepts what it is handed, which is what `any` says.
    public var declared: TypeExpression { type ?? .any }

    // MARK: - Initializer
    public init(
        type: TypeExpression? = nil,
        candidates: [String]? = nil,
        default: Value? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.candidates = candidates
        self.default = `default`
        self.description = description
    }

    // MARK: - Public
    // A host's door onto the boundary a run keeps: this parameter lowered
    // into the slot the run reads, and the value settled by it.
    public func taking(
        _ value: Value,
        called name: Name,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(named: name, in: types.loweredTypes).taking(value, in: types.loweredTypes)
    }

    public func checking(
        receiver value: Value,
        called name: Name,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(named: name, in: types.loweredTypes).checking(receiver: value, in: types.loweredTypes)
    }

    public func checking(
        _ value: Value,
        called name: Name,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(named: name, in: types.loweredTypes).checking(value, in: types.loweredTypes)
    }

    // MARK: - Private
}
