//
//  Linked.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A declaration, or a closure literal, read against a lowered type table: the
// parameters as a run settles them and what the answer settles against, which
// are that table's rows. What a document settles without one is `Judged`.
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
        case native(Native)
    }

    // MARK: - Property
    // The declared spelling, or the spelling of the declaration a closure was
    // written in.
    public let label: Name

    // Which document declared it, whose variables its body reads.
    public let origin: Int

    // Which of its label's closures this row is, for a row a closure literal
    // was lifted into: the declaration that wrote it and this count are what
    // a closure value is spelled by. Nil for a declaration's own row.
    let nth: Int?

    // The hop a trace takes into this row: a declaration by its spelling, a
    // closure by which of its writer's it is.
    var hop: Trace.Hop {
        nth.map { nth in .closure(of: label.spelling, nth: nth) } ?? .procedure(label.spelling)
    }

    // What a refusal calls this row.
    var rendered: String { hop.rendered }

    public let signature: Signature

    // Who may name this row: its own document, the link, or the caller too.
    public let access: Access

    public let constness: Constness
    public let isolation: Isolation

    // What may come out of this when the work goes wrong: the procedures its
    // failures name themselves by. Read off the body's casts, calls and
    // rescues, or declared by the native procedure.
    public let failing: Failing

    // The parameters as the run settles them, in the same order, and what
    // the answer settles against. The declaration's lowering, born here
    // from the signature beside it.
    let slots: [Slot]
    let returns: LoweredType?

    // The table the slots' rows are numbered by. A row means something in
    // its own link alone, and a closure value carries its row out of a run,
    // so a run that is handed one asks whether it was made by the same link.
    let table: LoweredTypeTable

    // The sends this row's procedure declared, in the places the procedure names them
    // at: the row each reaches and where what it hands over stands. Empty for a
    // body, whose sends are calls its own code carries.
    let sends: [Sent]

    let implementation: Implementation

    // Whether a fold may run this. A body is read from the text an object is
    // keyed by and the specification says what its own procedures answer, so
    // both fold to a value that means the same wherever the object is read. A
    // procedure a caller brought answers what its code answers, which is
    // written down nowhere the object goes.
    let foldable: Bool

    static let unreadable = "got a procedure a row of this link cannot read."
        + " One is read where the link that made it is being read, which"
        + " for a judgment is the image's own types"

    // The same row as a fold reads it: what a caller brought answers with the
    // refusal it earns there, and everything else answers as it is.
    var folding: Linked {
        guard !foldable else { return self }

        return Linked(self, implementation: .native(.query(UnfoldableProcedure(label))), sends: sends)
    }

    // Whether this row is a written body.
    public var isWritten: Bool {
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
        sends: [Sent] = [],
        nth: Int? = nil,
        in table: LoweredTypeTable
    ) {
        let slots = signature.lowered(in: table)
        let returns = signature.returns?.lowered(in: table)

        self.label = label
        self.origin = origin
        self.nth = nth
        self.signature = signature
        self.access = access
        self.constness = constness
        self.isolation = isolation
        self.slots = slots
        self.returns = returns
        self.failing = failing
        self.table = table
        self.sends = sends
        self.implementation = implementation
        self.foldable = foldable
    }

    // The same row read against another table. A compile that lays more
    // documents beside the one this came out of numbers their types past the
    // ones here and moves none of them, so the slots stand as they are and are
    // carried over rather than lowered a second time. What changes is the
    // table the row settles a call against, which is the one the compile is
    // asking with: its rows carry what that compile has worked out and what it
    // is still owed.
    init(_ row: Linked, in table: LoweredTypeTable) {
        self.label = row.label
        self.origin = row.origin
        self.nth = row.nth
        self.signature = row.signature
        self.access = row.access
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = table
        self.sends = row.sends
        self.implementation = row.implementation
        self.foldable = row.foldable
    }

    // The same row holding different code. What a row lowered from its
    // signature is the signature's, and neither lowering a body nor answering
    // the numbers in one touches the signature, so the slots are carried over
    // rather than worked out again.
    init(_ row: Linked, implementation: Implementation, sends: [Sent]) {
        self.label = row.label
        self.origin = row.origin
        self.nth = row.nth
        self.signature = row.signature
        self.access = row.access
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = row.table
        self.sends = sends
        self.implementation = implementation
        self.foldable = row.foldable
    }

    // MARK: - Public
    // A declaration's row before its body is lowered: a native answers as it
    // is, and a written body stands as the refusal it earns until then, so
    // nothing folds through a body half-made. Until it is lowered such a row
    // is not written, since what it holds is the refusal.
    static func standing(
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
            implementation: .native(native ?? .query(UnsettledProcedure())),
            foldable: native == nil || builtin,
            sends: sends,
            in: table
        )
    }

    // The boundary this row keeps, over arguments standing at their slot's
    // position, read by this row's own table: the slots' rows are numbered by
    // it and by nothing else. `skipping` names the positions a call fills
    // another way.
    func settle(
        _ given: [Value?],
        skipping: (Int) -> Bool = { _ in false }
    ) throws -> [Value?] {
        try signature.settle(given, over: slots, skipping: skipping, in: table)
    }

    // The same, over arguments handed by position: the way every call hands
    // them.
    func settle(applied given: [Value]) throws -> [Value] {
        try signature.settle(applied: given, over: slots, in: table)
    }

    // The same, over arguments given by name: the door a caller outside the
    // build comes through.
    func settle(_ given: [Name: Value]) throws -> [Value?] {
        try signature.settle(given, over: slots, in: table)
    }

    // The returned value, checked against what was declared.
    func settling(returned value: Value) throws -> Value {
        guard let returns else { return value }

        return try returns.settling(value, at: "returns", in: table)
    }

    // Whether a run reading that table can read this row: the row was made
    // by the same link.
    func readable(in other: LoweredTypeTable) -> Bool {
        table.linkage === other.linkage
    }

    // One row with every lowered type its body stands on answered again. The
    // only: what a row's slots and answer lower to is its signature read
    // against a table, which is the link's reading and not a number the
    // document gave. That holds for a native, which has no body at all, and
    // for a written one.
    func renumbered(_ answer: (LoweredType) throws -> LoweredType) rethrows -> Linked {
        guard case let .body(body, frame) = implementation else { return self }

        return Linked(
            self,
            implementation: .body(try Self.renumbered(body, answer), frame),
            sends: sends
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

        case .native:
            return (sends.map(\.row), [])
        }
    }

    // MARK: - Private
    private static func renumbered(
        _ body: LoweredBody,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> LoweredBody {
        LoweredBody(
            instructions: try body.instructions.map { instruction in
                try Self.renumbered(instruction, answer)
            },
            result: try body.result.map { result in try Self.renumbered(result, answer) }
        )
    }

    private static func renumbered(
        _ instruction: Instruction,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Instruction {
        Instruction(
            binding: try Self.renumbered(instruction.binding, answer),
            code: try Self.renumbered(instruction.code, answer),
            label: instruction.label
        )
    }

    private static func renumbered(
        _ binding: Instruction.Binding?,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Instruction.Binding? {
        switch binding {
        case let .bind(slot, settling)?:
            return .bind(slot, settling: try settling.map { type in try answer(type) })

        case let .declare(slot, settling)?:
            return .declare(slot, settling: try settling.map { type in try answer(type) })

        case let .assign(address, settling)?:
            return .assign(address, settling: try settling.map { type in try answer(type) })

        case nil:
            return nil
        }
    }

    private static func renumbered(
        _ operation: Operation,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Operation {
        switch operation {
        case .literal, .local:
            return operation

        case let .array(elements):
            return .array(try elements.map { element in try Self.renumbered(element, answer) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try Self.renumbered(field, answer) }
                )
            )

        // A closure stands as a row of its own, which this walk reaches on its
        // own turn. What is written here is the number that reaches it, and a
        // number carries no type.
        case .closure:
            return operation

        case let .apply(callee, arguments):
            return .apply(
                try Self.renumbered(callee, answer),
                arguments: try arguments.map { argument in try Self.renumbered(argument, answer) }
            )

        case let .cast(value, type, optional):
            return .cast(
                try Self.renumbered(value, answer),
                as: try answer(type),
                optional: optional
            )

        case let .block(body):
            return .block(try Self.renumbered(body, answer))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try Self.renumbered(condition, answer),
                then: try then.map { instruction in try Self.renumbered(instruction, answer) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try Self.renumbered(instruction, answer) }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try Self.renumbered(condition, answer),
                body: try Self.renumbered(body, answer),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try Self.renumbered(body, answer),
                rescue: try Self.renumbered(rescue, answer),
                failure: failure
            )

        case let .call(call):
            return .call(try Self.renumbered(call, answer))

        // The calls a dispatch picks from are the link's to fill, so there is
        // nothing here for a document to number.
        case let .dispatch(dispatch):
            return .dispatch(
                DispatchOperation(
                    contract: dispatch.contract,
                    procedure: dispatch.procedure,
                    first: try Self.renumbered(dispatch.first, answer),
                    arguments: try dispatch.arguments.map { argument in
                        try Self.renumbered(argument, answer)
                    },
                    calls: dispatch.calls
                )
            )

        case let .leave(reach, target, value):
            return .leave(
                reach,
                target: target,
                try value.map { value in try Self.renumbered(value, answer) }
            )
        }
    }

    private static func renumbered(
        _ call: CallOperation,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> CallOperation {
        CallOperation(
            procedure: call.procedure,
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try Self.renumbered(operation, answer) }
            },
            handed: call.handed
        )
    }

    private static func renumbered(
        _ argument: Argument,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Argument {
        switch argument {
        case let .value(operation):
            return .value(try Self.renumbered(operation, answer))

        case .reference:
            return argument
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
