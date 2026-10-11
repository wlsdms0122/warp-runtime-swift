//
//  Linked.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A declaration, or a closure literal, read against a lowered type table: the
// parameters a door settles values at and the answer a host's is settled
// against, which are that table's rows. What a document settles without one
// is `Judged`.
//
// A written body is lowered code with its frame layout; a native answers as it
// is. A class, so a call reads it without copying it and a closure value holds
// its own.
//
// Both stand as rows of the table a run reads. A closure literal has no
// declared spelling, so no table of names reaches it and `Operation.closure`
// carries the number that does.
public final class Linked: Sendable {
    enum Implementation: Sendable {
        case body(LoweredBody, Frame)

        // The sends the procedure declared, in the places it names them at:
        // the row each reaches and where what it hands over stands. A body's
        // sends are calls its own code carries.
        case native(Native, sends: [Sent])
    }

    // MARK: - Property
    // The declared spelling, or the spelling of the declaration a closure was
    // written in.
    public let label: Name

    // Which document declared it, whose variables its body reads.
    public let origin: Int

    // Which closure this row is, for a row a closure literal was lifted
    // into: the declaration that wrote it and which of that declaration's it
    // is, what a closure value is spelled by. Nil for a declaration's own row.
    let closure: (by: Closure.Declaration, nth: Int)?

    // The hop a trace takes into this row: a declaration by its spelling, a
    // closure by which of its writer's it is.
    var hop: Trace.Hop {
        closure.map { closure in .closure(of: label.spelling, nth: closure.nth) } ?? .procedure(label.spelling)
    }

    // What a refusal calls this row.
    var rendered: String { hop.rendered }

    public let signature: Signature

    // Who may name this row: its own document, the link, or the host too.
    public let access: Access

    public let constness: Constness
    public let isolation: Isolation

    // What may come out of this when the work goes wrong: the procedures its
    // failures name themselves by. Read off the body's casts, calls and
    // rescues, or declared by the native procedure.
    public let failing: Failing

    // The parameters a door settles values at, in the same order, and the
    // answer a host's is settled against. The declaration's lowering, born
    // here from the signature beside it.
    let slots: [Slot]
    let returns: LoweredType?

    // The table the slots' rows are numbered by. A row means something in
    // its own link alone, and a closure value carries its row out of a run,
    // so a run that is handed one asks whether it was made by the same link.
    let table: LoweredTypeTable

    let implementation: Implementation

    // Whether a fold may run this. A body is read from the text an object is
    // keyed by and the specification says what its own procedures answer, so
    // both fold to a value that means the same wherever the object is read. A
    // procedure a host brought answers what its code answers, which is
    // written down nowhere the object goes.
    let foldable: Bool

    static let unreadable = "got a procedure a row of this link cannot read."
        + " One is read where the link that made it is being read, which"
        + " for a judgement is the image's own types"

    // The same row as a fold reads it: what a host brought answers with the
    // refusal it earns there, and everything else answers as it is.
    var folding: Linked {
        guard !foldable else { return self }

        return Linked(self, implementation: .native(.query(UnfoldableProcedure(label)), sends: sends))
    }

    // The sends a native declared, which a call it makes reaches by place.
    // A body names none.
    var sends: [Sent] {
        guard case let .native(_, sends) = implementation else { return [] }

        return sends
    }

    // The send a native declared at a place, which a call it makes reaches.
    func sent(_ position: Int, as selector: Name) throws -> Sent {
        guard sends.indices.contains(position) else {
            throw ExecutionError("'\(rendered)' sends '\(selector)', and the link resolved no row for it")
        }

        return sends[position]
    }

    // Whether this row is a written body.
    var isWritten: Bool {
        if case .body = implementation { return true }

        return false
    }

    // MARK: - Initializer
    init(
        label: Name,
        origin: Int,
        signature: Signature,
        access: Access,
        constness: Constness,
        isolation: Isolation,
        failing: Failing,
        implementation: Implementation,
        foldable: Bool,
        closure: (by: Closure.Declaration, nth: Int)? = nil,
        in table: LoweredTypeTable
    ) {
        let slots = signature.lowered(in: table)
        let returns = signature.returns?.lowered(in: table, bounds: signature.bounds)

        self.label = label
        self.origin = origin
        self.closure = closure
        self.signature = signature
        self.access = access
        self.constness = constness
        self.isolation = isolation
        self.slots = slots
        self.returns = returns
        self.failing = failing
        self.table = table
        self.implementation = implementation
        self.foldable = foldable
    }

    // The same row read against another table. A compile that lays more
    // documents beside the one this came out of numbers their types past the
    // ones here and moves none of them, so the slots stand as they are and are
    // carried over rather than lowered a second time. What changes is the
    // table the row reads its types by, which is the one the compile is
    // asking with: its rows carry what that compile has worked out and what it
    // is still owed.
    init(_ row: Linked, in table: LoweredTypeTable) {
        self.label = row.label
        self.origin = row.origin
        self.closure = row.closure
        self.signature = row.signature
        self.access = row.access
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = table
        self.implementation = row.implementation
        self.foldable = row.foldable
    }

    // The same row holding different code. What a row lowered from its
    // signature is the signature's, and neither lowering a body nor answering
    // the numbers in one touches the signature, so the slots are carried over
    // rather than worked out again.
    init(_ row: Linked, implementation: Implementation) {
        self.label = row.label
        self.origin = row.origin
        self.closure = row.closure
        self.signature = row.signature
        self.access = row.access
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = row.table
        self.implementation = implementation
        self.foldable = row.foldable
    }

    // MARK: - Public
    // A declaration's row before its body is lowered: a native answers as it
    // is, and a written body stands as the refusal it earns until then, so
    // nothing folds through a body half-made. Until it is lowered such a row
    // is not written, since what it holds is the refusal.
    static func unlowered(
        label: Name,
        origin: Int,
        procedure: Procedure,
        const: Bool,
        isolated: Bool,
        failing: Failing,
        builtin: Bool,
        sends: [Sent],
        in table: LoweredTypeTable
    ) -> Linked {
        let native = procedure.implementation.native

        return Linked(
            label: label,
            origin: origin,
            signature: procedure.signature,
            access: procedure.access,
            constness: const ? .const : .unstated,
            isolation: isolated ? .isolated : .unstated,
            failing: failing,
            implementation: .native(native ?? .query(UnsettledProcedure()), sends: sends),
            foldable: native == nil || builtin,
            in: table
        )
    }

    // How many arguments a call hands, against the slots this row keeps: a
    // host's, at the door, and a value call's, whose count an object may
    // write. Either is about to place values in a frame, so another one is
    // refused rather than trapped on.
    func refuseCount(_ count: Int) throws {
        guard count == slots.count else {
            throw ArgumentError("'\(rendered)' was given \(count) arguments, and it takes \(slots.count)")
        }
    }

    // Arguments handed by position from outside the build: the door a host
    // hands a closure values through, and a procedure the host answers its
    // sends. One for each slot, settled together by the door rule.
    func settle(outside given: [Value]) throws -> [Value] {
        try refuseInPlace()
        try refuseCount(given.count)

        return try settled(given)
    }

    // Arguments given by name: the door a run's entry is handed values
    // through, settled into the order a run keeps them in. A name the
    // declaration lacks is refused, and so is one it declares that was not
    // given; a null standing at a name was given, since null is a value the
    // way any other is. They are settled together by the door rule.
    func settle(_ given: [Name: Value]) throws -> [Value] {
        try refuseInPlace()

        let undeclared = given.keys
            .filter { name in !slots.contains { slot in slot.name == name } }
            .sorted()

        guard undeclared.isEmpty else {
            throw ArgumentError(
                "entry '\(label)' declares no parameter"
                    + " \(undeclared.map { name in "'\(name)'" }.joined(separator: ", "))"
            )
        }

        let values = slots.compactMap { slot in given[slot.name] }

        guard values.count == slots.count else {
            let missing = slots.filter { slot in given[slot.name] == nil }.map { slot in "'\(slot.name)'" }

            throw ArgumentError("entry '\(label)' was given nothing for \(missing.joined(separator: ", "))")
        }

        return try settled(values)
    }

    // What a procedure the host answers hands back, a value from outside at
    // the door it comes through: fitted to what the row declares and judged
    // against it, `Any` where it declares nothing, which is what the build
    // reads such a call's answer as.
    func settling(answered value: Value) throws -> Value {
        try (returns ?? .any).settling(outside: value, at: "returns", in: table)
    }

    // Whether a run reading that table can read this row: the row was made
    // by the same link.
    func readable(in other: LoweredTypeTable) -> Bool {
        table.linkage === other.linkage
    }

    // One row with every lowered type its body stands on answered again. What
    // a row's slots and answer lower to is its signature read against a
    // table, so the body is all there is to answer, and a native has none.
    func renumbered(_ answer: (LoweredType) throws -> LoweredType) rethrows -> Linked {
        guard case let .body(body, frame) = implementation else { return self }

        return Linked(
            self,
            implementation: .body(try body.rewritten(operation: { operation in operation }, type: answer), frame)
        )
    }

    // What this row can send a run into: what its body names, the closures
    // the variables it reads start out holding, since a body applies what it
    // reads out of one without naming it, or the sends a native declared.
    // The variables are its own document's, by the number it gave them.
    func reaches(starting variables: [(name: Name, value: Value)]) -> (rows: [Int], held: [Linked]) {
        switch implementation {
        case let .body(body, frame):
            var reach = Self.reached(by: body)

            for (variable, _) in frame.variables {
                variables[variable].value.closures { closure in closure.linked.map { linked in reach.held.append(linked) } }
            }

            return reach

        case let .native(_, sends):
            return (sends.map(\.row), [])
        }
    }

    // How many arguments a call a body stands hands, against the slots this
    // row keeps, which a run fills by position. Asked where the call's number
    // is first answered with this row: by a compile laying documents already
    // compiled down, and by a link.
    func refuseCall(standing arguments: Int, at place: Place) throws {
        guard arguments == slots.count else {
            throw BuildError(
                "a call stands \(arguments) argument(s) where the \(slots.count) its callee declares stand",
                at: place
            )
        }
    }

    // MARK: - Private
    // A value from outside is no variable, so a row taking one in place takes
    // nothing through a door.
    private func refuseInPlace() throws {
        guard let slot = slots.first(where: { slot in slot.type.isInout }) else { return }

        throw ArgumentError("'\(rendered)' takes '\(slot.name)' in place, and a value from outside is no variable")
    }

    // Values from outside, one at each slot, settled together in the door's
    // one order: each value's record names held and the value fitted to its
    // slot, the type parameters the slots name filled by what the fitted
    // values read as, and each value judged at its slot so filled.
    private func settled(_ values: [Value]) throws -> [Value] {
        let fitted = try zip(slots, values).map { slot, value in
            try slot.type.fitted(outside: value, at: "input '\(slot.name)'", in: table)
        }
        let filling = try filling(by: fitted)

        return try zip(slots, fitted).map { slot, value in
            try slot.type.filling(filling).settling(value, at: "input '\(slot.name)'", in: table)
        }
    }

    // What the type parameters this row's slots name stand for where values
    // cross the door at them, as the call the door is. What each fitted
    // value reads as fills them the way a call's readings fill a
    // declaration's, so the door judges a value as the build judges a
    // reading there, in the build's words. A type parameter is one type: one filled by two types
    // refuses, and so does a bounded one filled by a value of more than one
    // type. What fills a bounded one is then held to its bounds, and `Any`,
    // what values of several types join to, answers none. A parameter only a
    // procedure's own signature reaches is left standing, for the judgement
    // of that procedure to fill.
    //
    // A closure's type parameters are its writer's, filled by the call that
    // made it, which no value at this door says, so they stand as they are
    // and each value is held to the bounds alone.
    private func filling(by values: [Value]) throws -> [Name: LoweredType] {
        let types = slots.map(\.type)
        let parameters = types.reduce(into: [Name: [Name]]()) { found, type in
            found.merge(type.typeParameters) { first, _ in first }
        }

        guard closure == nil, !parameters.isEmpty else { return [:] }

        let substitution = Substitution(
            filling: types,
            against: values.map { value in LoweredType(of: value, in: table) },
            in: table
        )

        for (parameter, bounds) in parameters.sorted(by: { $0.key < $1.key }) {
            let refusal = substitution.disagreement(of: parameter, in: table)
                ?? substitution.severalTypes(of: parameter, bounds: Set(bounds), over: types, in: table)
                ?? substitution.unanswered(parameter, bounds: Set(bounds), in: table) { claim in
                    table.fulfillment?.require(folded: claim)
                }

            if let refusal {
                let standing = slots
                    .filter { slot in slot.type.typeParameters[parameter] != nil }
                    .map { slot in "input '\(slot.name)'" }
                    .joined(separator: ", ")

                throw ArgumentError("\(standing): \(refusal)")
            }
        }

        return parameters.reduce(into: [:]) { filled, parameter in
            let (name, bounds) = parameter

            filled[name] = substitution.readings[name] ?? .parameter(label: name, bounds: bounds)
        }
    }

    // The rows a body can send a run into, read off its code: every call, every
    // row that answers a contract it calls through, and every closure it writes,
    // whose body is a row of its own. Read once the link has answered every
    // number with a row, so what comes back is rows of this link. A closure a
    // value holds is spelled by its writer, and the link says which row that is.
    private static func reached(by body: LoweredBody) -> (rows: [Int], held: [Linked]) {
        var rows: [Int] = []
        var held: [Linked] = []

        body.walk { node in
            reached(by: node, into: &rows, holding: &held)

            return true
        }

        return (rows, held)
    }

    // The rows one node sends a run into, apart from what nests in it, and the
    // rows the closures its values hold stand in. A closure a value holds was
    // answered by the link before this is asked, so one holding no row is none
    // this walk was handed.
    private static func reached(by node: LoweredBody.Node, into rows: inout [Int], holding held: inout [Linked]) {
        guard case let .operation(operation) = node else { return }

        switch operation {
        case let .literal(value):
            value.closures { closure in closure.linked.map { linked in held.append(linked) } }

        case let .closure(row, _):
            rows.append(row)

        case let .call(call):
            rows.append(call.procedure)

        case let .dispatch(dispatch):
            dispatch.calls.values.forEach { call in rows.append(call.procedure) }

        case .local, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
            break
        }
    }
}
