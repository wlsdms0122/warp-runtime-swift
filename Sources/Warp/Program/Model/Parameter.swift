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
        guard let table = try? types.lowered() else { return true }

        return mustBeGiven(in: table)
    }

    // The half that needs no table is answered first: a default answers
    // omission whatever the type says. A type nothing declares spells no
    // null, the way it did before it was lowered.
    func mustBeGiven(in table: ShapeTable) -> Bool {
        guard `default` == nil else { return false }

        return !((try? declared.lowered(in: table))?.declaresNull(in: table) ?? false)
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
        try taking(value, called: name, in: try types.lowered())
    }

    func taking(_ value: Value, called name: String, in table: ShapeTable) throws -> Value {
        try lowered(named: name, in: table).taking(value, in: table)
    }

    public func checking(
        receiver value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        let table = try types.lowered()

        return try lowered(named: name, in: table).checking(receiver: value, in: table)
    }

    public func checking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        let table = try types.lowered()

        return try lowered(named: name, in: table).checking(value, in: table)
    }

    // A candidate of `oneOf` read as the number its canonical spelling
    // names for the declared slot, the way the boundary reads it, so the
    // link's candidate judge and the boundary agree on which members exist.
    static func numeral(
        _ candidate: String,
        as declared: TypeExpression?,
        in types: TypeTable
    ) -> Value? {
        guard let table = try? types.lowered(), let shape = try? (declared ?? .any).lowered(in: table) else {
            return nil
        }

        return shape.numeral(candidate, in: table)
    }

    // MARK: - Private
}
