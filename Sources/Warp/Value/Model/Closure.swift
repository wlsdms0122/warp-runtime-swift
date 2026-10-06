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
    // it is read by.
    let slotAnswers: [LoweredType]

    // What a call of it settles its answer to, in turn: its own `returns`,
    // then every answer a slot it was settled into wrote, so the closure
    // answers what every slot it passed through made of it, wherever it is
    // called from. A slot judges it by these, and `settling` is a call doing
    // so.
    var answerTypes: [LoweredType] {
        [linked?.returns].compactMap { returns in returns } + slotAnswers
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
        linked: Linked?,
        captured: [(slot: Int, cell: Cell)],
        slotAnswers: [LoweredType] = []
    ) {
        self.writer = writer
        self.nth = nth
        self.linked = linked
        self.captured = captured
        self.slotAnswers = slotAnswers
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

    // What a call of it answers, settled the way `answerTypes` says: its own
    // `returns` settled what its body answered, as every procedure's does,
    // and each answer a slot wrote settles it in turn from there.
    func settling(_ answered: Value, in table: LoweredTypeTable) throws -> Value {
        try slotAnswers.reduce(answered) { answered, answer in
            try answer.settling(answered, at: "answer", in: table)
        }
    }

    // The same closure as a link reads it: the body standing in that link's
    // tables. What a slot wrote for its answer is read into that link's rows
    // by the walk that reads the value holding the closure.
    func standing(as linked: Linked) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, slotAnswers: slotAnswers)
    }

    // The same closure holding something else.
    func holding(_ captured: [(slot: Int, cell: Cell)]) -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, slotAnswers: slotAnswers)
    }

    // The same closure settled into a slot that wrote `returns` for its
    // answer: one more answer a call settles to, unless settling to it
    // leaves what the closure answers last unchanged, which adds nothing to
    // what a call makes of the answer. An answer met one step back that the
    // last one hands back as it was ends the list there again, since
    // settling to it, to the last, and to it once more is settling to it
    // once. Every other answer stays, since a slot taking one does not say
    // what it said.
    func passing(_ returns: LoweredType, in table: LoweredTypeTable) -> Closure {
        if let last = answerTypes.last, returns.settlesUnchanged(last, in: table) { return self }

        if slotAnswers.count >= 2,
           let last = slotAnswers.last,
           slotAnswers[slotAnswers.count - 2].identical(to: returns, in: table),
           returns.settlesBack(through: last, in: table) {
            return Closure(writer: writer, nth: nth, linked: linked, captured: captured, slotAnswers: slotAnswers.dropLast())
        }

        return Closure(writer: writer, nth: nth, linked: linked, captured: captured, slotAnswers: slotAnswers + [returns])
    }

    // The same closure with every answer it keeps read through `type`.
    func retyped(_ type: (LoweredType) throws -> LoweredType) rethrows -> Closure {
        Closure(writer: writer, nth: nth, linked: linked, captured: captured, slotAnswers: try slotAnswers.map(type))
    }

    // MARK: - Private
}
