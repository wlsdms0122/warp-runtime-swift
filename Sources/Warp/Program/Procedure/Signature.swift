//
//  Signature.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a call is checked against, in both directions: what it takes and what
// comes back.
public struct Signature: Sendable, Equatable {
    // MARK: - Property
    // What the declaration takes, in the order it wrote them. The order is the
    // declaration's own: it is the order every call hands its arguments in,
    // and the order the run keeps them in.
    public let parameters: [Parameter]

    // What a call returns, or nil where nothing was declared. A call reads a
    // declaration writing none as what its body answers, and one writing
    // `Any` as `Any`.
    public let returns: TypeExpression?

    // The contracts each type parameter is bounded by, by its name. The
    // signature owns the bound, so one name is held to one set however many
    // slots mention it, and a name absent here is bounded by nothing.
    public let bounds: [Name: Set<Name>]

    // The members of its type parameters it says are a type, by the label a
    // member is written under, `T.Item`. What fills `T` must give that type
    // there, and inside the declaration the member is that type.
    public let sameTypes: [Name: TypeExpression]

    // The declared names in position order.
    public var names: [Name] {
        parameters.map(\.name)
    }

    // The type a value of this declaration carries: the parameter types in
    // position order and the answer. No names, since a value is applied by
    // position and the names are the declaration's own.
    public var type: ProcedureType {
        ProcedureType(parameters: parameters.map(\.type), returns: returns)
    }

    // The parameters whose box is the body's own. One handed in place is the
    // caller's box, written through rather than held.
    var ownedParameters: Set<Name> {
        Set(parameters.compactMap { parameter in parameter.type.isInout ? nil : parameter.name })
    }

    // The first parameter handed in place, which only a call a body writes
    // can fill.
    var inPlace: Name? {
        parameters.first { parameter in parameter.type.isInout }?.name
    }

    // Whether the declaration writes a type parameter anywhere.
    var isGeneric: Bool { type.isGeneric }

    // Every type parameter this signature names. A nested procedure type's
    // parameters are named too: they are this signature's own slots, so
    // `Array<some Element>` beside a procedure taking the same `some Element`
    // is one parameter filled by one call.
    var parameterNames: Set<Name> { type.parameterNames }

    // Every declared name this signature reaches, through what it takes, what
    // it answers and the contracts its bounds name.
    var mentions: Set<Name> {
        let said = sameTypes.values.reduce(into: Set(bounds.values.joined())) { mentioned, type in
            mentioned.formUnion(type.mentions)
        }

        return parameters.reduce(into: (returns?.mentions ?? []).union(said)) { mentioned, parameter in
            mentioned.formUnion(parameter.type.mentions)
        }
    }

    // Every member of a type parameter this names, by its label, beside the
    // parameter and the name: in what it takes and answers, what its same
    // types say and the members its bounds and same types are written under.
    var members: [Name: (of: Name, name: Name)] {
        let written = ([returns].compactMap { $0 } + parameters.map(\.type) + Array(sameTypes.values))
            .reduce(into: [Name: (of: Name, name: Name)]()) { found, type in
                found.merge(type.members) { first, _ in first }
            }

        return Set(bounds.keys).union(sameTypes.keys).reduce(into: written) { found, key in
            if let member = key.memberOf { found[key] = member }
        }
    }

    // MARK: - Initializer
    // A name bounded by no contract is a name bounded by nothing, so it
    // stands nowhere in `bounds`.
    public init(
        parameters: [Parameter] = [],
        returns: TypeExpression? = nil,
        bounds: [Name: Set<Name>] = [:],
        sameTypes: [Name: TypeExpression] = [:]
    ) {
        self.parameters = parameters
        self.returns = returns
        self.bounds = bounds.filter { _, contracts in !contracts.isEmpty }
        self.sameTypes = sameTypes
    }

    // A native procedure's declaration, read off the procedure itself. What it takes is
    // its own type's to say, so a registration names the procedure once and the
    // parameters come with it, in the order its cases stand. `bounds` are what
    // its type parameters are held to, as a document's signature writes them.
    public init<P: NativeProcedure>(
        of procedure: P.Type,
        returns: TypeExpression? = nil,
        bounds: [Name: Set<Name>] = [:],
        sameTypes: [Name: TypeExpression] = [:]
    ) {
        self.init(
            parameters: P.Parameters.allCases.map(\.declared),
            returns: returns,
            bounds: bounds,
            sameTypes: sameTypes
        )
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
        parameters.map { parameter in parameter.lowered(in: table, bounds: bounds, sameTypes: sameTypes) }
    }

    // What this declaration answers as the run reads it, or nil where it
    // writes no `returns`.
    func loweredReturns(in table: LoweredTypeTable) -> LoweredType? {
        returns?.lowered(in: table, bounds: bounds, sameTypes: sameTypes)
    }

    // Each member this says is a type, as the declaration reads that type.
    func loweredSameTypes(in table: LoweredTypeTable) -> [Name: LoweredType] {
        loweredMembers(in: table).filter { label, _ in sameTypes[label] != nil }
    }

    // Each member this names as the declaration reads it, by its label: the
    // type its same types say, or one type the declaration does not know,
    // held to what bounds it.
    func loweredMembers(in table: LoweredTypeTable) -> [Name: LoweredType] {
        members.reduce(into: [:]) { lowered, entry in
            lowered[entry.key] = TypeExpression.member(of: entry.value.of, name: entry.value.name)
                .lowered(in: table, bounds: bounds, sameTypes: sameTypes)
        }
    }

    // A closure's signature as the procedure it is written in reads it: each
    // type parameter it names, and each member of one, held to the bounds
    // `declared` gives that name and said to be what `said` says, since the
    // procedure around it owns the name.
    func bounded(by declared: [Name: Set<Name>], sameTypes said: [Name: TypeExpression] = [:]) -> Signature {
        let named = parameterNames.union(members.values.map(\.of))

        return Signature(
            parameters: parameters,
            returns: returns,
            bounds: declared.filter { name, _ in named.contains(name.memberOf?.of ?? name) },
            sameTypes: said.filter { label, _ in named.contains(label.memberOf?.of ?? label) }
        )
    }

    // A member's signature as the head it is given under reads it: each type
    // parameter it names that the head names is held to the head's bounds
    // beside its own, since the head says where the member applies.
    func under(_ head: Head) -> Signature {
        let named = parameterNames

        return Signature(
            parameters: parameters,
            returns: returns,
            bounds: head.bounds.filter { name, _ in named.contains(name) }.merging(bounds) { theirs, mine in
                theirs.union(mine)
            },
            sameTypes: sameTypes
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
            bounds: read.bounds.merging([TypeSpelling.selfType: [contract]]) { _, contract in contract },
            sameTypes: read.sameTypes
        )
    }

    // This signature with `Self` written as `type` wherever it stands.
    func replacingSelf(with type: TypeExpression) -> Signature {
        Signature(
            parameters: parameters.map { parameter in
                Parameter(
                    name: parameter.name,
                    type: parameter.type.replacingSelf(with: type),
                    description: parameter.description
                )
            },
            returns: returns?.replacingSelf(with: type),
            bounds: bounds,
            sameTypes: sameTypes.mapValues { same in same.replacingSelf(with: type) }
        )
    }

    // MARK: - Private
}
