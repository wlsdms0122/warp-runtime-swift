//
//  Signature.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a call is checked against, in both directions. What it takes and what
// comes back. Declaring only the inward half would stop the judgement this
// language makes before running at the boundary it is easiest to make it at.
public struct Signature: Sendable, Equatable {
    // MARK: - Property
    // What the declaration takes, in the order it wrote them. The order is the
    // declaration's own: it is the order every call hands its arguments in,
    // and the order the run keeps them in.
    public let parameters: [Parameter]

    // What a call returns, or nil where nothing was declared. Absence is
    // spelled by being absent rather than by a type meaning "no claim". `Any`
    // is a claim, so a declaration nobody wrote stays distinguishable from one
    // somebody wrote. Nothing is checked either way; they differ in what they
    // say.
    public let returns: TypeExpression?

    // The contracts each type parameter is bounded by, by its name. The
    // signature owns the bound, so one name is held to one set however many
    // slots mention it, and a name absent here is bounded by nothing.
    public let bounds: [Name: Set<Name>]

    // The declared names in position order.
    public var names: [Name] {
        parameters.map(\.name)
    }

    // The type a value of this declaration carries: the parameter types in
    // position order and the answer. No names, since a value is applied by
    // position and the names are the declaration's own.
    public var type: ProcedureType {
        ProcedureType(parameters: parameters.map(\.declared), returns: returns)
    }

    // The parameters whose box is the body's own. One handed in place is the
    // caller's box, written through rather than held.
    var ownedParameters: Set<Name> {
        Set(parameters.compactMap { parameter in parameter.declared.isInout ? nil : parameter.name })
    }

    // The first parameter handed in place, which only a call a body writes
    // can fill.
    var inPlace: Name? {
        parameters.first { parameter in parameter.declared.isInout }?.name
    }

    // Whether the declaration writes a type parameter anywhere.
    public var isGeneric: Bool { type.isGeneric }

    // Every type parameter this signature names. A nested procedure type's
    // parameters are named too: they are this signature's own slots, so
    // `Array<some Element>` beside a procedure taking the same `some Element`
    // is one parameter filled by one call.
    var parameterNames: Set<Name> { type.parameterNames }

    // Every declared name this signature reaches, through what it takes, what
    // it answers and the contracts its bounds name.
    var mentions: Set<Name> {
        parameters.reduce(into: (returns?.mentions ?? []).union(bounds.values.joined())) { mentioned, parameter in
            mentioned.formUnion(parameter.declared.mentions)
        }
    }

    // MARK: - Initializer
    // A name bounded by no contract is a name bounded by nothing, so it
    // stands nowhere in `bounds`.
    public init(parameters: [Parameter] = [], returns: TypeExpression? = nil, bounds: [Name: Set<Name>] = [:]) {
        self.parameters = parameters
        self.returns = returns
        self.bounds = bounds.filter { _, contracts in !contracts.isEmpty }
    }

    // A native procedure's declaration, read off the procedure itself. What it takes is
    // its own type's to say, so a registration names the procedure once and the
    // parameters come with it, in the order its cases stand.
    public init<P: NativeProcedure>(of procedure: P.Type, returns: TypeExpression? = nil) {
        self.init(parameters: P.Parameters.allCases.map(\.declared), returns: returns)
    }

    // MARK: - Public
    // The parameter declared under a name, or nil where none is.
    public func parameter(named name: Name) -> Parameter? {
        parameters.first { parameter in parameter.name == name }
    }

    // Where a name stands among the parameters, or nil where none is
    // declared under it.
    public func position(of name: Name) -> Int? {
        parameters.firstIndex { parameter in parameter.name == name }
    }

    // This declaration as the run reads it: its parameters as slots, in
    // position order, each type parameter held to its bounds.
    func lowered(in table: LoweredTypeTable) -> [Slot] {
        parameters.map { parameter in parameter.lowered(in: table, bounds: bounds) }
    }

    // The same, with what a call put in the type parameters written in. The
    // filling happens on the lowered type rather than on the declaration,
    // because what a call read is a type and a declaration is a document's
    // spelling.
    func lowered(in table: LoweredTypeTable, filling bound: [Name: LoweredType]) -> [Slot] {
        parameters.map { parameter in parameter.lowered(in: table, bounds: bounds, filling: bound) }
    }

    // Whether a value declared this way may stand where this is required.
    //
    // The directions are opposite on purpose: what is given must accept
    // everything that will be passed to it, and what is required must accept
    // everything it will get back. A body promising less than the slot asks and
    // returning more than the slot allows is the one that fits.
    public func accepts(_ given: Signature, in types: TypeTable = .empty) -> Bool {
        let table = types.loweredTypes

        return TypeExpression.procedure(type).lowered(in: table, bounds: bounds)
            .accepts(TypeExpression.procedure(given.type).lowered(in: table, bounds: given.bounds), in: table)
    }

    // A closure's signature as the procedure it is written in reads it: each
    // type parameter it names held to the bounds `declared` gives that name,
    // since the procedure around it owns the name.
    func bounded(by declared: [Name: Set<Name>]) -> Signature {
        let named = parameterNames

        return Signature(
            parameters: parameters,
            returns: returns,
            bounds: declared.filter { name, _ in named.contains(name) }
        )
    }

    // A contract's procedure as a call through the contract reads it: `Self`
    // as one type parameter the contract bounds, which every position
    // writing it shares.
    func read(of contract: Name) -> Signature {
        let read = replacingSelf(with: .parameter(name: TypeSpelling.selfType))

        return Signature(
            parameters: read.parameters,
            returns: read.returns,
            bounds: read.bounds.merging([TypeSpelling.selfType: [contract]]) { _, contract in contract }
        )
    }

    // This signature with `Self` written as `type` wherever it stands.
    func replacingSelf(with type: TypeExpression) -> Signature {
        Signature(
            parameters: parameters.map { parameter in
                Parameter(
                    name: parameter.name,
                    type: parameter.type?.replacingSelf(with: type),
                    description: parameter.description
                )
            },
            returns: returns?.replacingSelf(with: type),
            bounds: bounds
        )
    }

    // Arguments given by name, settled into the order a run keeps them in.
    // A name the declaration lacks is refused, and so is one it declares that
    // was not given. A door a host outside the build comes through, since
    // the build resolves names itself, and so a value is fitted to its type
    // here, a field the declaration never named left out.
    // `subject` is what a refusal names the procedure as.
    func settle(
        _ given: [Name: Value],
        over slots: [Slot],
        as subject: String,
        in table: LoweredTypeTable
    ) throws -> [Value?] {
        let undeclared = given.keys
            .filter { name in !slots.contains { slot in slot.name == name } }
            .sorted()

        guard undeclared.isEmpty else {
            throw ArgumentError(
                "\(subject) declares no parameter"
                    + " \(undeclared.map { name in "'\(name)'" }.joined(separator: ", "))"
            )
        }

        return try settle(
            slots.map { slot in given[slot.name].map { value in slot.type.fitted(value, in: table) } },
            over: slots,
            as: subject,
            in: table
        )
    }

    // Arguments handed by position, the way every call hands them: one for
    // each slot, and none handed in place.
    func settle(
        applied given: [Value],
        over slots: [Slot],
        as subject: String,
        in table: LoweredTypeTable
    ) throws -> [Value] {
        guard given.count == slots.count else {
            throw ArgumentError(
                "\(subject) was given \(given.count) arguments, and it takes \(slots.count)"
            )
        }

        return try zip(slots, given).map { slot, value in
            try slot.checking(value, at: "input '\(slot.name)'", in: table)
        }
    }

    // The boundary itself, over arguments standing at their parameter's
    // position. `skipping` names the positions a call fills another way, a
    // parameter handed a variable in place, and those answer nil. `judging`
    // names the positions judged at their slot; the rest are handed over as
    // they are. The answer is built from the declaration, never copied from
    // the caller: only declared names exist inside the boundary.
    func settle(
        _ given: [Value?],
        over slots: [Slot],
        skipping: (Int) -> Bool = { _ in false },
        judging: (Int) -> Bool = { _ in true },
        as subject: String,
        in table: LoweredTypeTable
    ) throws -> [Value?] {
        guard given.count == slots.count else {
            throw ArgumentError(
                "\(subject) was given \(given.count) arguments, and it takes \(slots.count)"
            )
        }

        // A null standing at a slot was given: null is a value the way any
        // other is, and a caller that holds one hands it over rather than
        // falling silent.
        let missing = slots.indices
            .filter { position in !skipping(position) && given[position] == nil }
            .map { position in "'\(slots[position].name)'" }

        guard missing.isEmpty else {
            throw ArgumentError(
                "\(subject) was given nothing for \(missing.joined(separator: ", "))"
            )
        }

        var settled: [Value?] = Array(repeating: nil, count: slots.count)

        for (position, slot) in slots.enumerated() {
            guard let value = given[position] else { continue }

            settled[position] = judging(position) ? try slot.checking(value, at: "input '\(slot.name)'", in: table) : value
        }

        return settled
    }

    // MARK: - Private

}
