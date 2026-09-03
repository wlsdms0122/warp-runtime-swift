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
    // any shape is welcome; nil is the absence of a claim. Neither is checked,
    // and keeping them apart is what lets the ones written on purpose be told
    // from the ones nobody got around to.
    public let type: TypeExpression?
    public let oneOf: [String]?
    public let `default`: Value?
    public let hint: String?

    // Whether a call must write this argument — the one question, answered in
    // one place for the call check, the boundary and path reachability alike.
    // A default answers omission with a value; a type that declares null
    // (`T?`) answers it with the null it holds. Without either, omission is a
    // missing argument. Optionality has no third axis.
    public func mustBeGiven(in types: TypeTable) -> Bool {
        mustBeGiven(in: types.shapes)
    }

    // The slot's question, asked through the slot. The name is a refusal's
    // and no refusal is made here.
    func mustBeGiven(in table: ShapeTable) -> Bool {
        lowered(named: "", in: table).mustBeGiven(in: table)
    }

    // What this reads as where a type is needed regardless. An undeclared
    // parameter accepts what it is handed, which is what `any` says.
    public var declared: TypeExpression { type ?? .any }

    // MARK: - Initializer
    public init(
        type: TypeExpression? = nil,
        oneOf: [String]? = nil,
        default: Value? = nil,
        hint: String? = nil
    ) {
        self.type = type
        self.oneOf = oneOf
        self.default = `default`
        self.hint = hint
    }

    // MARK: - Public
    // A host's door onto the boundary a run keeps: this parameter lowered
    // into the slot the run reads, and the value settled by it.
    public func taking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        try lowered(named: name, in: types.shapes).taking(value, in: types.shapes)
    }

    public func checking(
        receiver value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        try lowered(named: name, in: types.shapes).checking(receiver: value, in: types.shapes)
    }

    public func checking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        try lowered(named: name, in: types.shapes).checking(value, in: types.shapes)
    }

    // A candidate of `oneOf` read as the number its canonical spelling
    // names for the declared slot, the way the boundary reads it, so the
    // link's candidate judge and the boundary agree on which members exist.
    static func numeral(
        _ candidate: String,
        as declared: TypeExpression?,
        in types: TypeTable
    ) -> Value? {
        (declared ?? .any).lowered(in: types.shapes).numeral(candidate, in: types.shapes)
    }

    // MARK: - Private
}
