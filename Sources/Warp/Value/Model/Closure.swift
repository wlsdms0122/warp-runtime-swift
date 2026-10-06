//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A procedure as a value: which closure it is, the row a link answered for
// it, and the cells it took from the frame it was written in, each with the
// slot it fills in the closure's own frame. A value cell was copied; a hold
// shares its box.
//
// Which closure it is, is spelled by its writer and which of the writer's it
// is: what an object writes a closure down as, and what a link answers a row
// for. A closure a fold settled into an object stands by that spelling alone
// until the link reading the object answers it. No position in any link
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

    // MARK: - Property
    let writer: Writer
    let nth: Int

    let linked: Linked?
    let captured: [(slot: Int, cell: Cell)]

    // What the slots this closure was settled into wrote for its answer, in
    // the order it met them and in the rows of the table the value holding
    // it is read by. Every call settles the answer to each in turn after the
    // closure's own `returns`, so the closure answers what every slot it
    // passed through made of it, wherever it is called from.
    let answering: [LoweredType]

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
        linked: Linked?,
        captured: [(slot: Int, cell: Cell)],
        answering: [LoweredType] = []
    ) {
        self.writer = writer
        self.nth = nth
        self.linked = linked
        self.captured = captured
        self.answering = answering
    }

    // MARK: - Public
    // The row a link answered for this closure. A closure reaches a run only
    // through a link, so one without a row there is one no link read. A
    // settling reads the row for itself, since it refuses in its caller's
    // words.
    public func answered() throws -> Linked {
        guard let linked else { throw ExecutionError("a closure no link answered") }

        return linked
    }

    // The same closure as a link reads it: the body standing in that link's
    // tables. What a slot wrote for its answer is read into that link's rows
    // by the walk that reads the value holding the closure.
    func standing(as linked: Linked) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, answering: answering)
    }

    // The same closure holding something else.
    func holding(_ captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, answering: answering)
    }

    // The same closure answering through `kept` instead.
    func settled(answering kept: [LoweredType]) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, answering: kept)
    }

    // The same closure with every answer it keeps read through `type`.
    func retyped(_ type: (LoweredType) throws -> LoweredType) rethrows -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, answering: try answering.map(type))
    }

    // MARK: - Private
}
