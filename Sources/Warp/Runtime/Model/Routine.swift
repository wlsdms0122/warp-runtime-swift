//
//  Routine.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// One row of a code table, and its body compiled where it is one. A call compiled against
// the row holds this and reaches the body through it, so a body calling
// itself is compiled once, and one compiled before the table was handed out
// is read without a lock.
final class Routine: @unchecked Sendable {
    // MARK: - Property
    let linked: Linked

    // The hop a trace takes into the row.
    let hop: Trace.Hop

    // What fills the row's type parameters where the body is compiled for
    // one call's types, and nil where it is compiled for every call.
    let filled: [Name: LoweredType]?

    // The table compiles the body, and holds this.
    private unowned let table: CodeTable

    private var compiled: CompiledBody?

    // Nil where the table compiled the body before it was handed out, so
    // what is read was written before any run could read it.
    private let lock: NSLock?

    // MARK: - Initializer
    init(_ linked: Linked, in table: CodeTable, filled: [Name: LoweredType]? = nil, lazily: Bool) {
        self.linked = linked
        self.hop = linked.hop
        self.filled = filled
        self.table = table
        self.lock = lazily ? NSLock() : nil
    }

    // MARK: - Public
    // The row's body, compiled: the one the table compiled as it was made,
    // or the one compiled the first time a call reached it.
    func body(_ lowered: LoweredBody, in frame: Frame) -> CompiledBody {
        guard let lock else { return compiled ?? table.compile(lowered, in: frame, of: linked, filled: filled) }

        return lock.withLock {
            if let compiled { return compiled }

            let made = table.compile(lowered, in: frame, of: linked, filled: filled)

            compiled = made

            return made
        }
    }

    // The body compiled while the table is being made, before any run reads
    // it. A native row has none.
    func compile() {
        guard case let .body(lowered, frame) = linked.implementation else { return }

        compiled = table.compile(lowered, in: frame, of: linked, filled: filled)
    }

    // MARK: - Private
}
