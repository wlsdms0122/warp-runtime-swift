//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A procedure as a value: which closure it is, the row a link resolved for
// it, and the cells it took from the frame it was written in, each with the
// slot it fills in the closure's own frame. A value cell was copied; a hold
// shares its box.
//
// Which closure it is, is spelled by its writer and which of the writer's it
// is: what an object writes a closure down as, and what a link resolves a row
// for. A closure folded into an object at the build stands by that spelling
// alone until the link reading the object resolves it. No position in any link
// rides along: a compiled document is laid into whatever link a host makes
// of it, in whatever order, and a spelling is what survives that.
public struct Closure: Sendable {
    // The declaration that wrote a closure, in the document it stands in. A
    // constant's spelling is its document's own, so the document is part of
    // the name.
    struct Writer: Hashable, Sendable {
        // MARK: - Property
        let document: Document
        let declaration: Declaration

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // Which of its document's declarations wrote a closure. A procedure and a
    // constant may be spelled alike, so the kind is part of it.
    enum Declaration: Hashable, Comparable, Sendable {
        case procedure(Name)

        // A constant or a variable, which share one namespace.
        case binding(Name)

        // MARK: - Property
        var name: Name {
            switch self {
            case let .procedure(name), let .binding(name): name
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // Procedures before bindings, and each in name order: the order a
        // document numbers the closures its declarations wrote in.
        static func < (lhs: Declaration, rhs: Declaration) -> Bool {
            switch (lhs, rhs) {
            case let (.procedure(left), .procedure(right)), let (.binding(left), .binding(right)):
                return left < right

            case (.procedure, .binding):
                return true

            case (.binding, .procedure):
                return false
            }
        }

        // MARK: - Private
    }

    // How a writer's document is told from another: by the text it was read
    // from where it was written down, and by the compile that made it
    // otherwise. The second names nothing outside the link it was compiled
    // for, and an object spells only the first.
    enum Document: Hashable, Sendable {
        case written(Identity)
        case compiled(Compiled.Token)

        // MARK: - Property
        // MARK: - Initializer
        // The one rule: the text where there is one, the compile otherwise.
        init(identity: Identity?, token: Compiled.Token) {
            self = identity.map(Document.written) ?? .compiled(token)
        }

        // MARK: - Public
        // MARK: - Private
    }

    // Where a closure stands, and what fills each type parameter of the body
    // that wrote it, by label, as the activation that made it held them. A
    // closure read back from an object stands by its spelling alone and
    // holds them spelled as a document writes a type, by name, since a type's
    // number is its table's. One a link resolved stands as its row and holds
    // them read in that row's tables, so its body reads them as the activation
    // that made it would, and its signature is known wherever it goes.
    enum Resolution: Sendable {
        case spelled(types: [Name: TypeExpression])
        case resolved(Linked, types: [Name: LoweredType])
    }

    // MARK: - Property
    let writer: Writer
    let nth: Int

    let resolution: Resolution
    let captured: [(slot: Int, cell: Cell)]

    // The row a link resolved for it, where one did.
    var linked: Linked? {
        guard case let .resolved(linked, _) = resolution else { return nil }

        return linked
    }

    // What a refusal calls this closure, spelled as the hop a trace takes
    // into its body.
    var rendered: String {
        Trace.Hop.closure(of: writer.declaration.name.spelling, nth: nth).rendered
    }

    // Whether a cell it took is a hold rather than a copy: a box of the
    // frame it was written in, shared with it.
    var tookAHold: Bool {
        captured.contains { _, cell in
            if case .hold = cell { return true }

            return false
        }
    }

    // MARK: - Initializer
    init(
        writer: Writer,
        nth: Int,
        resolution: Resolution,
        captured: [(slot: Int, cell: Cell)]
    ) {
        self.writer = writer
        self.nth = nth
        self.resolution = resolution
        self.captured = captured
    }

    // MARK: - Public
    // The row a link resolved for this closure, and the types it holds read
    // in that row's tables. A closure reaches a run only through a link, so
    // one without a row there is one no link read. A settling reads the row
    // for itself, since it refuses in its caller's words.
    func resolved() throws -> (row: Linked, types: [Name: LoweredType]) {
        guard case let .resolved(linked, types) = resolution else {
            throw ExecutionError("a closure no link resolved")
        }

        return (linked, types)
    }

    // The same closure as a link reads it: the body standing in that link's
    // tables, and the types it holds and those the values it captured hold
    // read in them by their names.
    func standing(as linked: Linked) -> Closure {
        if case let .resolved(row, types) = resolution, row.table.linkage === linked.table.linkage {
            return Closure(writer: writer, nth: nth, resolution: .resolved(linked, types: types), captured: captured)
        }

        let spelled = spelled()

        return Closure(
            writer: writer,
            nth: nth,
            resolution: .resolved(linked, types: spelled.types.mapValues { type in type.lowered(in: linked.table) }),
            captured: spelled.captured.map { slot, cell in
                guard case let .value(held) = cell else { return (slot, cell) }

                return (slot, .value(held.standing(in: linked.table)))
            }
        )
    }

    // What fills its writer's type parameters and what it captured, with
    // every type they hold spelled by name: what an object writes, and what
    // a link reads in its own tables. A resolved closure's types are numbered
    // in its row's tables.
    func spelled() -> (types: [Name: TypeExpression], captured: [(slot: Int, cell: Cell)]) {
        switch resolution {
        case let .spelled(types):
            return (types, captured)

        case let .resolved(row, types):
            return (
                types.mapValues { type in type.spelled(in: row.table) },
                captured.map { slot, cell in
                    guard case let .value(held) = cell else { return (slot, cell) }

                    return (slot, .value(held.spelled(in: row.table)))
                }
            )
        }
    }

    // The same closure holding something else.
    func holding(_ captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(writer: writer, nth: nth, resolution: resolution, captured: captured)
    }

    // MARK: - Private
}
