//
//  Signature.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a call is checked against, in both directions — what it takes and what
// comes back. Declaring only the inward half would stop the judgement this
// language makes before running at the boundary it is easiest to make it at.
public struct Signature: Sendable, Equatable {
    // MARK: - Property
    // Which declared parameter is the receiver — the thing this is sent *to* —
    // or nil for a plain call, which most procedures are.
    //
    // A name rather than a type, so the body reads its receiver by the name it
    // declared, the same as every other parameter — a reserved spelling would be
    // the alternative. Declaring a receiver is the whole of what makes a word
    // reachable through a path: it is what lets `x.name` find it.
    public let receiver: String?

    public let parameters: [String: Parameter]

    // What a call returns, or nil where nothing was declared. Absence is spelled
    // by being absent rather than by a type meaning "no claim" — `any` is a
    // claim, so a declaration nobody wrote stays distinguishable from one
    // somebody wrote. Nothing is checked either way; they differ in what they
    // say.
    //
    // Settable only from here, so `answering(_:)` changes this one field of a
    // copy instead of naming every field to keep it — a listing that keeps
    // fields by naming them loses a new one silently, and the initializer's
    // defaults mean nothing would say so.
    public private(set) var returns: TypeExpression?

    // MARK: - Initializer
    public init(
        receiver: String? = nil,
        parameters: [String: Parameter] = [:],
        returns: TypeExpression? = nil
    ) {
        self.receiver = receiver
        self.parameters = parameters
        self.returns = returns
    }

    // MARK: - Public
    // The same declaration with an answer where nobody wrote one. What the
    // author wrote is never replaced: a declaration is a promise, and one read
    // off a body is what the link worked out rather than what anybody
    // promised — so this is what the link reads a call as, and never what the
    // image carries or the boundary checks.
    func answering(_ answer: TypeExpression?) -> Signature {
        guard returns == nil, let answer else { return self }

        var answered = self
        answered.returns = answer

        return answered
    }

    // The returned value, checked against what was declared. Run time rather
    // than link time because what a body computes is not a thing the linker can
    // read off the text — but a declaration that only ever describes is a declaration
    // nothing keeps, so it is checked where the fact exists.
    public func settling(returned value: Value, in types: TypeTable = TypeTable()) throws -> Value {
        guard let returns else { return value }

        return try returns.settling(value, at: "returns", in: types)
    }

    // The receiver, checked against what the parameter naming it declares.
    public func settling(receiver value: Value, in types: TypeTable = TypeTable()) throws -> Value {
        guard let receiver, let parameter = parameters[receiver] else { return value }

        return try parameter.checking(receiver: value, called: receiver, in: types)
    }

    // This declaration as the run reads it: its parameters as slots, in
    // position order.
    func lowered(in table: ShapeTable) throws -> [Slot] {
        try ordered.map { name, parameter in try parameter.lowered(named: name, in: table) }
    }

    // Whether something declared this way may stand where this is required.
    //
    // The directions are opposite on purpose: what is given must accept
    // everything that will be passed to it, and what is required must accept
    // everything it will get back. A body promising less than the slot asks and
    // returning more than the slot allows is the one that fits.
    public func accepts(_ given: Signature, in types: TypeTable = TypeTable()) -> Bool {
        TypeExpression.procedure(self).accepts(.procedure(given), in: types)
    }

    // Whether a path segment may reach this — it takes a receiver, so there is
    // something for the walk to send it to, and it needs nothing else, so
    // `x.count` supplies everything it asks for.
    //
    // A declaration that answers `never` is reachable by neither: a path reads a
    // value, and this one leaves instead of producing one. Letting it in would
    // put the word that must not be missable where a walk decides on its own
    // whether to send it.
    public func isDerivable(in types: TypeTable) -> Bool {
        guard let table = try? types.lowered() else { return false }

        return isDerivable(in: table)
    }

    func isDerivable(in table: ShapeTable) -> Bool {
        guard let slots = try? lowered(in: table) else { return false }

        return slots.derivable(
            receiver: receiver.flatMap { name in slots.firstIndex { slot in Name.same(slot.name, name) } },
            returns: try? returns?.lowered(in: table),
            in: table
        )
    }

    // The expression a call hands under a parameter's name: the argument
    // written under it, or the receiver where the parameter is the receiver
    // and the call wrote one in front. One rule, asked wherever a call is
    // read.
    public func handed(
        _ name: String,
        receiver: Expression?,
        arguments: [String: Expression]
    ) -> Expression? {
        name == self.receiver
            ? receiver ?? arguments[name]
            : arguments[name]
    }

    // Inputs settle once at the scope boundary; inside the scope, references
    // read the settled values instead of re-evaluating. By name, for a caller
    // outside a run: the entry's arguments, a closure assembled in Swift.
    public func settle(
        _ given: [String: Value],
        in types: TypeTable = TypeTable()
    ) throws -> [String: Value] {
        let table = try types.lowered()
        let slots = try lowered(in: table)

        return named(try settle(given, over: slots, offered: false, in: table), over: slots)
    }

    // The same, for a caller that hands over more than the body asked for. A
    // word walking an array offers the element and whatever else it has, and
    // which of those the author wanted is the author's business: declaring a
    // name only to leave it unread is a declaration nobody meant.
    public func settle(
        offered given: [String: Value],
        in types: TypeTable = TypeTable()
    ) throws -> [String: Value] {
        let table = try types.lowered()
        let slots = try lowered(in: table)

        return named(try settle(given, over: slots, offered: true, in: table), over: slots)
    }

    // The parameters in the order arguments stand in.
    public var ordered: [(name: String, parameter: Parameter)] {
        parameters
            .sorted { left, right in Name.precedes(left.key, right.key) }
            .map { entry in (name: entry.key, parameter: entry.value) }
    }

    // MARK: - Internal
    // Arguments given by name, settled into the order a run keeps them in.
    // A name the declaration lacks is refused unless the caller offers.
    func settle(
        _ given: [String: Value],
        over slots: [Slot],
        offered: Bool,
        in table: ShapeTable
    ) throws -> [Value?] {
        try settle(given.map { name, value in (name: name, value: value) }, over: slots, offered: offered, in: table)
    }

    // Arguments given as a list of names and values, the way a word hands
    // them to a closure and a call of a value hands them to what it named.
    // Each slot finds its name along the list, so neither side hashes.
    func settle(
        _ given: [(name: String, value: Value)],
        over slots: [Slot],
        offered: Bool,
        in table: ShapeTable
    ) throws -> [Value?] {
        if !offered {
            let undeclared = given
                .map { entry in entry.name }
                .filter { name in !slots.contains { slot in Name.same(slot.name, name) } }
                .sorted(by: Name.precedes)

            guard undeclared.isEmpty else {
                throw ArgumentError(
                    "parameters: not declared in the signature:"
                        + " \(undeclared.joined(separator: ", "))"
                )
            }
        }

        // A name given twice is two instructions for one slot, and neither
        // is the one to keep.
        for (index, entry) in given.enumerated() {
            guard given[..<index].contains(where: { earlier in Name.same(earlier.name, entry.name) }) else { continue }

            throw ArgumentError("parameters: '\(entry.name)' is given more than once")
        }

        return try settle(
            slots.map { slot in given.first { entry in Name.same(entry.name, slot.name) }?.value },
            over: slots,
            offered: offered,
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
        in table: ShapeTable
    ) throws -> [Value?] {
        // What "nothing was given" means differs by who is giving. An author's
        // argument space folds null and unwritten into one instruction: a
        // reference that names nothing reads as null, and requiring the author
        // to know which is which would make absence observable. A word that
        // *offers* is the other way: it hands over values it actually holds,
        // and a null it offered is a value, an element of the walked
        // collection and not a blank, so only a position it never offered is
        // missing.
        var missing: [String] = []

        for (position, slot) in slots.enumerated() where !skipping(position) {
            let blank = offered ? given[position] == nil : (given[position] ?? .null) == .null

            if blank, slot.mustBeGiven(in: table) {
                missing.append(slot.name)
            }
        }

        guard missing.isEmpty else {
            throw ArgumentError(
                "parameters: required, and nothing was given for \(missing.joined(separator: ", "))"
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
    private func named(_ settled: [Value?], over slots: [Slot]) -> [String: Value] {
        var named: [String: Value] = [:]

        for (position, value) in settled.enumerated() {
            guard let value else { continue }

            named[slots[position].name] = value
        }

        return named
    }
}
