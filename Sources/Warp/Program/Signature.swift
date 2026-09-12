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
    // Which declared parameter is the receiver (the thing this is sent *to*) or
    // nil for a plain call, which most procedures are.
    //
    // A name rather than a type, so the body reads its receiver by the name it
    // declared, the same as every other parameter. A reserved spelling would be
    // the alternative. Declaring one is what lets a call write the receiver in
    // front of the selector rather than under its name.
    public let receiver: Name?

    // What the declaration takes, under the names it wrote them under. A
    // document writes them as a record, so the declaration says which
    // parameters there are and nothing about their order. Where a run needs
    // one, an argument's position is the names sorted, which `Name` orders and
    // the lowering puts in place.
    public let parameters: [Name: Parameter]

    // What a call returns, or nil where nothing was declared. Absence is
    // spelled by being absent rather than by a type meaning "no claim". `any`
    // is a claim, so a declaration nobody wrote stays distinguishable from one
    // somebody wrote. Nothing is checked either way; they differ in what they
    // say.
    public let returns: TypeExpression?

    // The parameters in the order arguments stand in, each read as whatever
    // the caller makes of it. A document writes them as a record, so the
    // declaration says which parameters there are and nothing about their
    // order; the order is the declared names sorted, and this is the one place
    // that says so.
    //
    // What each one is made into comes first because that is what the caller
    // came for, and `standing` says where to find the name on it. Made before
    // they are put in order, so nothing is built twice: one list, sorted where
    // it stands.
    func ordered<T>(_ make: (Name, Parameter) -> T, standing name: (T) -> Name) -> [T] {
        var made = parameters.map(make)

        made.sort { left, right in name(left) < name(right) }

        return made
    }

    // The declared names in that order, for a reader that wants the names and
    // nothing made of them.
    var names: [Name] {
        ordered({ name, _ in name }, standing: { name in name })
    }

    // MARK: - Initializer
    public init(
        receiver: Name? = nil,
        parameters: [Name: Parameter] = [:],
        returns: TypeExpression? = nil
    ) {
        self.receiver = receiver
        self.parameters = parameters
        self.returns = returns
    }

    // A native procedure's declaration, read off the procedure itself. What it takes is
    // its own type's to say, so a registration names the procedure once and the
    // parameters come with it.
    public init<P: NativeProcedure>(
        of procedure: P.Type,
        receiver: P.Parameters? = nil,
        returns: TypeExpression? = nil
    ) {
        self.init(
            receiver: receiver?.name,
            parameters: Dictionary(
                uniqueKeysWithValues: P.Parameters.allCases.map { key in
                    (key.name, key.declared)
                }
            ),
            returns: returns
        )
    }

    // The returned value, checked against what was declared. Run time rather
    // than link time because what a body computes is not a thing the builder can
    // read off the text, but a declaration that only ever describes is a
    // declaration nothing keeps, so it is checked where the fact exists.
    public func settling(returned value: Value, in types: TypeTable = .empty) throws -> Value {
        guard let returns else { return value }

        return try returns.settling(value, at: "returns", in: types)
    }

    // The receiver, checked against what the parameter naming it declares.
    public func settling(receiver value: Value, in types: TypeTable = .empty) throws -> Value {
        guard let receiver, let parameter = parameters[receiver] else { return value }

        return try parameter.checking(receiver: value, called: receiver, in: types)
    }

    // This declaration as the run reads it: its parameters as slots, in
    // position order.
    func lowered(in table: LoweredTypeTable) -> [Slot] {
        ordered(
            { name, parameter in parameter.lowered(named: name, in: table) },
            standing: { slot in slot.name }
        )
    }

    // The same, with what a call put in the type parameters written in. The
    // filling happens on the lowered shape rather than on the declaration,
    // because what a call read is a shape and a declaration is a document's
    // spelling.
    func lowered(in table: LoweredTypeTable, filling bound: [Name: LoweredType]) -> [Slot] {
        ordered(
            { name, parameter in parameter.lowered(named: name, in: table, filling: bound) },
            standing: { slot in slot.name }
        )
    }

    // Whether something declared this way may stand where this is required.
    //
    // The directions are opposite on purpose: what is given must accept
    // everything that will be passed to it, and what is required must accept
    // everything it will get back. A body promising less than the slot asks and
    // returning more than the slot allows is the one that fits.
    public func accepts(_ given: Signature, in types: TypeTable = .empty) -> Bool {
        TypeExpression.procedure(self).accepts(.procedure(given), in: types)
    }

    // The expression a call hands under a parameter's name: the argument
    // written under it, or the receiver where the parameter is the receiver
    // and the call wrote one in front. One rule, asked wherever a call is
    // read.
    public func handed(
        _ name: Name,
        receiver: Expression?,
        arguments: [Name: Expression]
    ) -> Expression? {
        name == self.receiver
            ? receiver ?? arguments[name]
            : arguments[name]
    }

    // Inputs settle once at the scope boundary; inside the scope, references
    // read the settled values instead of re-evaluating. By name, for a caller
    // outside a run: the entry's arguments, a closure assembled in Swift.
    public func settle(
        _ given: [Name: Value],
        in types: TypeTable = .empty
    ) throws -> [Name: Value] {
        let slots = lowered(in: types.loweredTypes)

        return named(try settle(given, over: slots, offered: false, in: types.loweredTypes), over: slots)
    }

    // The same, for a caller that hands over more than the body asked for. A
    // procedure walking an array offers the element and whatever else it has, and
    // which of those the author wanted is the author's business: declaring a
    // name only to leave it unread is a declaration nobody meant.
    public func settle(
        offered given: [Name: Value],
        in types: TypeTable = .empty
    ) throws -> [Name: Value] {
        let slots = lowered(in: types.loweredTypes)

        return named(try settle(given, over: slots, offered: true, in: types.loweredTypes), over: slots)
    }

    // MARK: - Internal
    // Every declared name this signature reaches, through what it takes and
    // what it answers.
    var mentions: Set<Name> {
        parameters.values.reduce(into: returns?.mentions ?? []) { mentioned, parameter in
            mentioned.formUnion(parameter.declared.mentions)
        }
    }

    // Arguments given by name, settled into the order a run keeps them in.
    // A name the declaration lacks is refused unless the caller offers.
    func settle(
        _ given: [Name: Value],
        over slots: [Slot],
        offered: Bool,
        in table: LoweredTypeTable
    ) throws -> [Value?] {
        try settle(given.map { name, value in (name: name, value: value) }, over: slots, offered: offered, in: table)
    }

    // Arguments given as a list of names and values, the way a procedure hands
    // them to a closure and a call of a value hands them to what it named.
    // Each slot finds its name along the list, so neither side hashes.
    func settle(
        _ given: [(name: Name, value: Value)],
        over slots: [Slot],
        offered: Bool,
        skipping: (Int) -> Bool = { _ in false },
        in table: LoweredTypeTable
    ) throws -> [Value?] {
        if !offered {
            let undeclared = given
                .map { entry in entry.name }
                .filter { name in !slots.contains { slot in slot.name == name } }
                .sorted()

            guard undeclared.isEmpty else {
                throw ArgumentError(
                    "parameters: not declared in the signature:"
                        + " \(undeclared.map(\.spelling).joined(separator: ", "))"
                )
            }
        }

        // A name given twice is two instructions for one slot, and neither
        // is the one to keep.
        for (index, entry) in given.enumerated() {
            guard given[..<index].contains(where: { earlier in earlier.name == entry.name }) else { continue }

            throw ArgumentError("parameters: '\(entry.name)' is given more than once")
        }

        return try settle(
            slots.map { slot in given.first { entry in entry.name == slot.name }?.value },
            over: slots,
            offered: offered,
            skipping: skipping,
            in: table
        )
    }

    // The boundary itself, over arguments standing at their parameter's
    // position. `skipping` names the positions a call fills another way, a
    // receiver written in front of the dot or a parameter handed a variable
    // in place, and those answer nil. The answer is built from the
    // declaration, never copied from the caller: only declared names exist
    // inside the boundary.
    func settle(
        _ given: [Value?],
        over slots: [Slot],
        offered: Bool,
        skipping: (Int) -> Bool = { _ in false },
        in table: LoweredTypeTable
    ) throws -> [Value?] {
        // What "nothing was given" means differs by who is giving. An author's
        // argument space folds null and unwritten into one instruction: a
        // reference that names nothing reads as null, and requiring the author
        // to know which is which would make absence observable. A procedure that
        // *offers* is the other way: it hands over values it actually holds,
        // and a null it offered is a value, an element of the walked
        // collection and not a blank, so only a position it never offered is
        // missing.
        var missing: [Name] = []

        for (position, slot) in slots.enumerated() where !skipping(position) {
            let blank = offered ? given[position] == nil : (given[position] ?? .null) == .null

            if blank, slot.mustBeGiven(in: table) {
                missing.append(slot.name)
            }
        }

        guard missing.isEmpty else {
            throw ArgumentError(
                "parameters: required, and nothing was given for"
                    + " \(missing.map(\.spelling).joined(separator: ", "))"
            )
        }

        var settled: [Value?] = Array(repeating: nil, count: slots.count)

        for (position, slot) in slots.enumerated() where !skipping(position) {
            // An offered null passes through as the value it is, for the same
            // reason it counted as given above.
            if offered, given[position] == .null {
                settled[position] = .null

                continue
            }

            settled[position] = try slot.taking(given[position] ?? .null, in: table)
        }

        return settled
    }

    // MARK: - Private
    private func named(_ settled: [Value?], over slots: [Slot]) -> [Name: Value] {
        var named: [Name: Value] = [:]

        for (position, value) in settled.enumerated() {
            guard let value else { continue }

            named[slots[position].name] = value
        }

        return named
    }
}
