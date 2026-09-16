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
        case body(Body, Frame)
        case native(Native)
    }

    // MARK: - Property
    // The declared spelling, or the spelling of the declaration a closure was
    // written in. What a trace and a refusal call this row.
    public let label: Name

    // Which document declared it, whose variables its body reads.
    public let origin: Int

    public let signature: Signature

    // Where the receiver stands among the slots, which is where it stands
    // among the parameters: a lowering reads a parameter's type and leaves
    // the order alone.
    public let receiverPosition: Int?

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

    // MARK: - Initializer
    init(
        label: Name,
        origin: Int,
        signature: Signature,
        constness: Constness,
        isolation: Isolation,
        failing: Failing,
        implementation: Implementation,
        sends: [Sent] = [],
        in table: LoweredTypeTable
    ) {
        let slots = signature.lowered(in: table)
        let returns = signature.returns?.lowered(in: table)
        let receiverPosition = slots.position(of: signature.receiver)

        self.label = label
        self.origin = origin
        self.signature = signature
        self.receiverPosition = receiverPosition
        self.constness = constness
        self.isolation = isolation
        self.slots = slots
        self.returns = returns
        self.failing = failing
        self.table = table
        self.sends = sends
        self.implementation = implementation
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
        self.signature = row.signature
        self.receiverPosition = row.receiverPosition
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = table
        self.sends = row.sends
        self.implementation = row.implementation
    }

    // The same row holding different code. What a row lowered from its
    // signature is the signature's, and neither lowering a body nor answering
    // the numbers in one touches the signature, so the slots are carried over
    // rather than worked out again.
    init(_ row: Linked, implementation: Implementation, sends: [Sent]) {
        self.label = row.label
        self.origin = row.origin
        self.signature = row.signature
        self.receiverPosition = row.receiverPosition
        self.constness = row.constness
        self.isolation = row.isolation
        self.slots = row.slots
        self.returns = row.returns
        self.failing = row.failing
        self.table = row.table
        self.sends = sends
        self.implementation = implementation
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
        sends: [Sent],
        in table: LoweredTypeTable
    ) -> Linked {
        Linked(
            label: label,
            origin: origin,
            signature: procedure.signature,
            constness: const ? .const : .unstated,
            isolation: isolated ? .isolated : .unstated,
            failing: failing,
            implementation: .native(procedure.implementation.native ?? .query(UnsettledProcedure())),
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

    // The same, over arguments given by name. `skipping` names the positions
    // the caller fills another way, as a receiver written in front of the dot
    // does.
    func settle(
        _ given: [(name: Name, value: Value)],
        skipping: (Int) -> Bool = { _ in false }
    ) throws -> [Value?] {
        try signature.settle(given, over: slots, skipping: skipping, in: table)
    }

    // The receiver settled against the slot at this row's receiver
    // position, or as it is where the row takes none.
    func settling(receiver value: Value) throws -> Value {
        guard let position = receiverPosition else { return value }

        return try slots[position].checking(receiver: value, in: table)
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

    static let unreadable = "got a procedure a row of this link cannot read."
        + " One is read where the link that made it is being read, which"
        + " for a judgment is the image's own types"

    // Whether this row is a written body.
    public var isWritten: Bool {
        if case .body = implementation { return true }

        return false
    }

    // MARK: - Private
}
