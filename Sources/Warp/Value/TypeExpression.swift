//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `ValueType`, which is what a
// value *is*: `any` is only ever something a declaration says, and `array` alone
// was the most a declaration could say about a list — no element, no fields, no
// name for a shape two procedures share.
//
// A type is an expression for the same reason an expression is: it composes.
// `array<string>` is `array` applied to `string`, and a name is a name for one
// of these rather than a separate kind of thing — which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// Checking is structural, and it is width-tolerant on records: a value with more
// fields than the declaration names passes. What arrives here is data from
// outside — a payload gains fields, and a declaration saying which ones it needs
// should not be a declaration that it needs nothing else to exist.
public indirect enum TypeExpression: Sendable, Equatable {
    // Nothing ever *is* `any` — it is what a declaration says when it accepts
    // whatever it is handed. `contains` compares elements of any shape, and
    // declaring `string` there would be a lie the linker would then enforce.
    case any

    // The other end of `any`. No value is ever of this type, which is how a
    // place control does not come back from is written down: a refusal answers
    // `never` because it does not answer at all. Saying so is what keeps the
    // arm that leaves from having an opinion about what the arm that stays
    // holds — without it, one branch failing would cost the other its type.
    case never

    case null
    case bool
    case int
    case double
    case string
    case bytes

    // Whole or fraction, without saying which.
    //
    // It exists because arithmetic is the one place a declaration genuinely
    // means both. Writing `any` there instead said nothing at all, so a sum of a
    // number and a piece of text was found by running it — in a language whose
    // whole claim is that what can be decided before running is.
    //
    // It is not a fourth number. Nothing is ever *of* this type: a value is
    // whole or it is a fraction, and this is what a slot says when either will
    // do. That makes it the numeric `any`, narrowed to the two shapes that
    // arithmetic can actually work with.
    case number

    // A number the slot admits only inside the range — `int(0...255)`,
    // `double(0.0..<1.0)`. The range is the slot's condition, not a new kind:
    // the value is a whole number or a fraction, and the bounds are judged
    // where a value is settled, the way `oneOf` is — at the link for a
    // constant, at the boundary for what only the run can see. A module gives
    // one a name the way it names any type: `byte = int(0...255)`.
    case ranged(Refinement)

    // A list of one shape. The element is always written, so `array<any>` says
    // out loud that anything is accepted — a declaration that accepts anything
    // reads differently from one that has not been written yet.
    case array(TypeExpression)

    // A map of string keys to one shape — a record whose field names are data
    // rather than declaration. Keys are always strings because that is what
    // `Value.object` holds.
    case object(TypeExpression)

    // Named fields with types. The value may carry more.
    case record([String: TypeExpression])

    // A value that can be called: what it may be called with, and what it must
    // be. Nil is a declaration that has not been written — "some procedure" —
    // the way `any` is for a value, and it is accepted by anything for the same
    // reason.
    //
    // Purity is a requirement rather than a claim. A declaration never states
    // its own — the linker derives that from what a body calls — so what is
    // written here is what a slot asks of whatever fills it.
    case procedure(Signature?, Purity = .unstated)

    // The declared type, or null — the one union the language has, and it is
    // null-only on purpose. `?.` answers this, and a parameter declaring it may
    // default to null; a general union would put back the "is it this or that"
    // question the whole type system exists to answer once.
    case nullable(TypeExpression)

    // A type a module declared. Kept rather than expanded so that a type may
    // name itself — `Tree` with children of `array<Tree>` is a shape, not a
    // regress — which means resolving one needs the table it was declared in.
    case named(String)

    // A type parameter, filled by whatever the call site puts there. The name
    // is what ties one signature's mentions together: `first` takes
    // `array<some T>` and answers `some T`, so an array of strings answers a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named` — a name is looked up in a table and this is worked out from the
    // call.
    //
    // The second name bounds it: a parameter bounded by `Comparable` takes only what the
    // constraint by that name admits. The constraint is a declaration like a
    // type — a module binds a name to the types it admits — so a signature
    // writes the name and never the membership, and there is no inline union
    // for the membership to leak out through.
    case variable(name: String, constraint: String? = nil)

    // What a walk *through* a type parameter reached. Still a shape the call
    // decides — a dot on it stands as written, the way a dot on the parameter
    // does — and not the parameter, because a field of an unknown shape is a
    // different unknown. It carries no bound for the same reason: what a
    // constraint admits was proven of the parameter, and nothing was proven of
    // what was read out of it.
    //
    // Apart from `variable` rather than spelled into one. Both are shapes the
    // link cannot see, but only one of them is a slot a call fills, and the
    // difference has to survive every way a type is built: a declaration is
    // written in a document *and* assembled in a host, and a rule the reader
    // alone enforces is a rule the host walks around. Two cases is that rule
    // stated where nothing can walk around it.
    //
    // The parameter it was read out of, and the path from there, together —
    // because that pair is the whole of what this is. Two walks that land on
    // the same field of the same unknown are one shape, and two fields of it
    // are two.
    //
    // Rooted at the parameter and not at the name a body happened to read
    // through: `of: some T` and `also: some T` are one unknown, so their
    // `.inner` is one field, and a step given a name along the way — `held =
    // of.inner` and then `held.count` — has to arrive where the unbroken walk
    // arrives. A root that was the local name made every naming a new unknown.
    //
    // The path is segments and not their spelling for the same reason: `.a`
    // and `?.a` land on one field, and a spelling would make them two unknowns
    // that never meet.
    case reading(of: String, path: [PathSegment])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // What this type accepts, settled to the declared representation, or a
    // refusal saying which part disagreed. `at` is the path into the value so
    // the message names the field rather than the whole argument.
    public func settling(
        _ value: Value,
        at path: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        try settling(value, at: path, in: types, assuming: [])
    }

    // What a cast does, said once. Both evaluators read a cast — the executor
    // for a body, the resolver for the pure half a constant folds through —
    // and they answer the same expression, so the rule is here rather than
    // twice over there. The judgment is `settling`'s; what this adds is the
    // one thing the cast spelling decides: what a mismatch means.
    func reading(_ value: Value, optional: Bool, in types: TypeTable) throws -> Value {
        do {
            return try settling(value, at: "as \(self)", in: types)
        } catch let mismatch as ArgumentError {
            // Only a mismatch is read as the author's expectation. Naming what
            // *is* absorbed rather than what is not keeps the default closed:
            // an error kind added later surfaces instead of quietly becoming
            // null, which is the failure this whole spelling exists against.
            // A name nothing declares already arrives as its own kind and
            // leaves through here untouched.
            guard optional else {
                // Recoverable, unlike the same refusal at a parameter's
                // boundary: a cast is the author expecting a shape of data
                // that came from outside, and being wrong about that is what
                // the world does. An `attempt` catches it.
                throw CastRefused(mismatch.message, shape: rendered)
            }

            return .null
        }
    }

    // The assumption-carrying half: which constraints are already being asked
    // of this value. A bounded parameter's membership test settles the value
    // against each member, and a member reaching a bounded parameter again
    // walks back into the same question — met again, it is assumed rather
    // than asked, so a table nothing linked still answers instead of chasing
    // a declaration the link would have refused.
    func settling(
        _ value: Value,
        at path: String,
        in types: TypeTable,
        assuming: Set<String>
    ) throws -> Value {
        switch self {
        case .any:
            return value

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal — there is no shape to compare it against.
        case .never:
            throw ArgumentError("\(path): declares never, and nothing is ever that")

        // Either shape arrives as itself. Settling to one of them would be the
        // declaration picking, and it declined to.
        case .number:
            switch value {
            case .int, .double:
                return value

            default:
                throw mismatch(value, at: path)
            }

        case let .named(name):
            guard let declared = types.resolve(name) else {
                throw UndeclaredTypeError(
                    "\(path): declares type '\(name)', which nothing declares"
                )
            }

            return try declared.settling(value, at: path, in: types, assuming: assuming)

        // Null arrives as itself; anything else is held to the declared half.
        case let .nullable(inner):
            guard value != .null else { return value }

            return try inner.settling(value, at: path, in: types, assuming: assuming)

        // A type parameter the call site filled, and the link is where it was
        // filled — unbounded, there is nothing left to compare against. A
        // bounded one still holds its constraint here: what arrived through
        // `any` was never read at the link, so membership is judged against
        // the types the constraint admits, and the value passes untouched —
        // a parameter stands for what arrived, it does not settle it.
        // Nothing was proven of what a walk read out of a parameter, so there
        // is nothing here to judge it against — it stands for what arrived,
        // the way an unbounded parameter does.
        case .reading:
            return value

        case let .variable(_, constraint):
            guard let constraint, !assuming.contains(constraint) else { return value }

            guard let admitted = types.admits(
                constraint: constraint,
                value: value,
                assuming: assuming.union([constraint])
            ) else {
                throw UndeclaredTypeError(
                    "\(path): declares constraint '\(constraint)', which nothing declares"
                )
            }

            guard admitted else {
                throw ArgumentError(
                    "\(path): expected \(rendered), and '\(constraint)' does not"
                        + " admit \(value.type)"
                )
            }

            return value

        case let .array(element):
            // Bytes are an array of bytes in a compact spelling, so they arrive
            // here as the array they are. Where the declaration leaves every
            // byte as it is, the compact spelling crosses whole — the slot
            // asked for an array and one is what it has, and unpacking it would
            // spend an element per byte to answer nothing.
            // `settling`'s own carried set is of constraint names, which is the
            // second of the two below.
            if case .bytes = value, element.holdsEveryByte(in: types, boundAssuming: assuming) {
                return value
            }

            // Otherwise the slot's spelling wins the way `double` settles a
            // whole number, and both spellings are read through the one
            // projection that owns the equation — so what is outside the
            // declaration says which element and by how much, whichever
            // spelling it arrived in.
            guard let items = value.elements else { throw mismatch(value, at: path) }

            return .array(
                try items.enumerated().map { index, item in
                    try element.settling(item, at: "\(path)[\(index)]", in: types, assuming: assuming)
                }
            )

        case let .object(entry):
            guard case let .object(object) = value else { throw mismatch(value, at: path) }

            return .object(
                try object.mapValues { item in
                    try entry.settling(item, at: path, in: types, assuming: assuming)
                }
            )

        case let .record(fields):
            guard case let .object(object) = value else { throw mismatch(value, at: path) }

            var settled = object

            for (name, field) in fields.sorted(by: { left, right in left.key < right.key }) {
                guard let written = object[name] else {
                    throw ArgumentError("\(path).\(name): required by \(rendered), and nothing was given")
                }

                settled[name] = try field.settling(
                    written,
                    at: "\(path).\(name)",
                    in: types,
                    assuming: assuming
                )
            }

            return settled.isEmpty ? .object([:]) : .object(settled)

        // Purity is not checked here. What a closure calls is a fact about the
        // text it was written in, which the link read and this cannot — a value
        // in hand carries a body, not the judgement made about it.
        case let .procedure(required, _):
            guard case let .procedure(closure) = value else { throw mismatch(value, at: path) }
            guard let required else { return value }

            guard required.accepts(closure.procedure.signature, in: types) else {
                throw ArgumentError(
                    "\(path): expected \(rendered), got"
                        + " \(TypeExpression.procedure(closure.procedure.signature).rendered)"
                )
            }

            return value

        // The bounds speak where the value does: a number inside them settles
        // as the kind's own value, and one outside is refused by the range
        // the declaration wrote.
        case let .ranged(refinement):
            switch refinement.settling(value) {
            case let .settled(settled):
                return settled

            case .otherKind:
                throw mismatch(value, at: path)

            case let .outside(number):
                throw ArgumentError("\(path): \(number) is outside \(rendered)")
            }

        // Bytes take their own spelling as themselves, and an array whose
        // every element is a byte's worth — settled to the compact spelling
        // the slot declared. The element judge is `byte`'s own, so what is
        // outside says which element and by how much.
        case .bytes:
            switch value {
            case .bytes:
                return value

            case let .array(elements):
                let bytes = try elements.enumerated().map { index, item in
                    let settled = try TypeExpression.byteElement.settling(
                        item,
                        at: "\(path)[\(index)]",
                        in: types,
                        assuming: assuming
                    )

                    // `byte`'s own judge already spoke: what settled is an
                    // int inside 0...255, which the canonical small form
                    // holds — a miss here is this file's own defect, not a
                    // refusal a program could see.
                    guard
                        case let .int(number) = settled,
                        let byte = UInt8(exactly: number)
                    else {
                        preconditionFailure("a settled byte was not one")
                    }

                    return byte
                }

                return .bytes(bytes)

            default:
                throw mismatch(value, at: path)
            }

        // The scalars, plus the one widening the language has, one way only:
        // an int where a double is declared. Nothing narrows — an int slot
        // refuses every fraction, `2.0` included.
        case .null, .bool, .int, .double, .string:
            guard let settled = scalar(value) else { throw mismatch(value, at: path) }

            return settled
        }
    }

    // How the type reads in a message. A declaration an author wrote should come
    // back to them in the spelling they wrote it in.
    public var rendered: String {
        switch self {
        case .any:
            return "any"

        case .never:
            return "never"

        case .number:
            return "number"

        case .null:
            return "null"

        case .bool:
            return "bool"

        case .int:
            return "int"

        case .double:
            return "double"

        case .string:
            return "string"

        case .bytes:
            return "bytes"

        case let .ranged(refinement):
            // The exact spelling: what is rendered here is written into
            // documents and compared as the type's identity, not a message.
            return refinement.rendered

        // The diagnostic voice, not the notation — `rendered` tells an author
        // what a type *is*, and the procedure case below already writes a
        // shape no document spells. So the bound rides along: `some N` alone
        // would hide the one fact a bound refusal is about. What a document
        // spells is the writer's question, and the writer answers it with
        // `bounds`.
        case let .variable(name, constraint):
            return constraint.map { bound in "some \(name): \(bound)" } ?? "some \(name)"

        // Spelled as what it is — the shape reached by that path. No document
        // writes this, so the spelling answers to the message alone: an author
        // reading a refusal about `item.a` should see where it came from.
        case let .reading(of, path):
            return "some \(([PathSegment.key(of)] + path).rendered)"

        case let .procedure(signature, purity):
            let word = purity == .pure ? "pure procedure" : "procedure"

            guard let signature else { return word }

            let written = signature.parameters
                .sorted { left, right in left.key < right.key }
                .map { name, parameter in "\(name): \(parameter.declared.rendered)" }

            // Rendered as what it accepts, because a message is about what would
            // have fit. Which half was written is a fact about the source rather
            // than about the value being refused.
            return "\(word)<(\(written.joined(separator: ", "))) -> \((signature.returns ?? .any).rendered)>"

        case let .array(element):
            return "array<\(element.rendered)>"

        case let .object(entry):
            return "object<\(entry.rendered)>"

        case let .record(fields):
            let written = fields
                .sorted { left, right in left.key < right.key }
                .map { name, field in "\(name): \(field.rendered)" }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(name):
            return name

        case let .nullable(inner):
            return "\(inner.rendered)?"
        }
    }

    // MARK: - Private
    // The one conversion the language performs, and it goes one way.
    //
    // Every whole number is a fraction, so a slot asking for a fraction can take
    // a whole one and lose nothing. The reverse is not true, and taking it when
    // the fraction happened to be whole would make the answer to "does this fit"
    // depend on the value rather than the type — `2.0` accepted where `2.5` is
    // refused, by a declaration that names neither.
    private func scalar(_ value: Value) -> Value? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double),
            (.string, .string):
            return value

        // The widening is binary64's own rounding, and every machine word has
        // a fraction near it — the conversion cannot fail, only round.
        case (.double, .int(let integer)):
            return .double(Double(integer))

        default:
            return nil
        }
    }

    private func mismatch(_ value: Value, at path: String) -> ArgumentError {
        ArgumentError("\(path): expected \(rendered), got \(value.type)")
    }
}

extension TypeExpression: CustomStringConvertible {
    public var description: String { rendered }
}

extension TypeExpression {
    // What one element of bytes is — the range `std` names `byte`. Owned here
    // because the `bytes = array<byte>` equation reads it without a link, so
    // it cannot live behind the name.
    static let byteElement = TypeExpression.ranged(.whole(from: 0, to: .through(255)))

    // Whether every byte settles into this element declaration as itself —
    // unchanged, and with nothing asked of any one of them.
    //
    // This is what lets a compact spelling cross a boundary whole. `bytes` is
    // `array<byte>`, so it arrives at every `array<…>` slot, and unpacking it
    // there costs a boxed element per byte to answer questions like `first`
    // that read one. Where the declaration would leave each byte exactly as it
    // is, the unpacking answers nothing and the compact spelling stands.
    //
    // It says the same thing `settling` says one byte at a time, which is a
    // second copy of one rule — so `aByteSettlesAsItselfExactlyWhereTheTypeSaysIt`
    // holds the two together over every byte and every shape below, and the
    // copy is a claim a test refutes rather than a comment.
    // The two sets are two namespaces. A table may bind one string as a type
    // and the same string as a constraint, and they are different declarations
    // — folding them into one guard would let a type's name end a constraint's
    // question by assuming it, which answers yes where the membership was
    // never asked.
    func holdsEveryByte(
        in types: TypeTable,
        namedAssuming: Set<String> = [],
        boundAssuming: Set<String> = []
    ) -> Bool {
        switch self {
        // Nothing is asked, so nothing is changed. A walk through a parameter
        // asks nothing either — it carries no bound to ask with.
        case .any, .int, .number, .reading:
            return true

        // A parameter stands for what arrived and does not settle it. A bounded
        // one still asks each value for its membership — and a member that
        // takes every byte answers that question for all of them at once, so
        // `sorted` reads a compact spelling the way `reversed` does rather than
        // by whether its declaration happened to carry a bound.
        case let .variable(_, constraint):
            guard let constraint else { return true }
            guard !boundAssuming.contains(constraint) else { return true }

            let deeper = boundAssuming.union([constraint])

            // A member that takes every byte on its own settles the whole
            // membership, because a membership is met when some member takes
            // the value. This is the shape every constraint anyone has written
            // has — `Comparable` holds `int` — and it costs one pass over the
            // members rather than a pass per byte.
            if
                let members = types.constraint(constraint),
                members.contains(where: { member in
                    member.holdsEveryByte(
                        in: types,
                        namedAssuming: namedAssuming,
                        boundAssuming: deeper
                    )
                })
            { return true }

            // No one member covers it, so the complete question is asked with
            // the boundary's own primitive: members that divide the range
            // between them still take every byte, and only asking each byte
            // sees that. Sufficient first, complete behind it — the cheap test
            // can only say yes where this one would.
            return (0 ... 255).allSatisfy { byte in
                types.admits(constraint: constraint, value: .int(byte), assuming: deeper) == true
            }

        // Null never arrives out of bytes, so the declared half decides alone.
        case let .nullable(inner):
            return inner.holdsEveryByte(
                in: types,
                namedAssuming: namedAssuming,
                boundAssuming: boundAssuming
            )

        // The bounds have to hold the whole of `byte`; a narrower range refuses
        // some byte, and which one it refuses is read out one by one.
        case let .ranged(refinement):
            return refinement.holdsEveryByte

        case let .named(name):
            guard
                let declared = types.resolve(name),
                !namedAssuming.contains(name)
            else { return false }

            return declared.holdsEveryByte(
                in: types,
                namedAssuming: namedAssuming.union([name]),
                boundAssuming: boundAssuming
            )

        // `double` is the one widening the language has, so it changes every
        // byte it takes; the rest take no byte at all. Named rather than left
        // to a default, so that a kind added to the type language has to be
        // answered for here too — this is the second copy of a rule, and the
        // copy is only safe while nothing can be added to one and not the
        // other.
        case .never, .null, .bool, .double, .string, .bytes,
             .array, .object, .record, .procedure:
            return false
        }
    }

    // The spelling with its conditions dropped: a range is an int the bounds
    // refine, and bytes are `array<byte>` compacted. This answers the kind
    // question alone — a join asks it, because a join's answer is a kind. It
    // is deliberately not a gate for `accepts` and `settling`: those exist to
    // read exactly what dropping erases — the bounds, and which spelling a
    // slot settles to.
    var unrefined: TypeExpression {
        switch self {
        case let .ranged(refinement):
            return refinement.kind

        case .bytes:
            return .array(.byteElement)

        default:
            return self
        }
    }
}

extension TypeExpression {
    // Whether what this stands for is settled at the call — the shallow
    // question, beside `isGeneric`'s deep one. A parameter and a walk through
    // one answer alike, and that is the whole of what is asked: neither is
    // knowable at the link, so a reading that would judge by shape has nothing
    // to judge on. Named for the question and not for one of the two shapes
    // that answer it.
    var decidedAtCall: Bool {
        switch self {
        case .variable, .reading:
            return true

        default:
            return false
        }
    }

    // What a walk through this shape reaches by taking those segments — nil
    // where this is not a shape a call decides, which is where a walk has a
    // type to read the segments against and no need for one of these.
    //
    // Asked of the shape rather than assembled at the walk, because the root
    // is the shape's own fact: a parameter roots a reading at itself, and a
    // reading already rooted extends the path it carries. Assembling it from
    // the segments a body happened to write is how a named step became a
    // second unknown.
    //
    // The marks come off on the way in: what a mark says is expected of the
    // value, and where the walk landed is the same field either way.
    func reaching(_ path: [PathSegment]) -> TypeExpression? {
        switch self {
        case let .variable(name, _):
            return .reading(of: name, path: path.map(\.unmarked))

        case let .reading(of, walked):
            return .reading(of: of, path: walked + path.map(\.unmarked))

        default:
            return nil
        }
    }

    // Whether this shape proves nothing about the value it holds — the three
    // that stop a walk, named once because they are one question asked twice.
    // A dot needs a shape the types prove, and a cast is the door onto one:
    // what the walk may not read past is exactly what a cast may open, and a
    // cast onto anything else is a claim the types already settled.
    //
    // The three say nothing for three different reasons, and where the reason
    // matters — the sentence a refusal carries — they are asked apart. This is
    // for the places that only need the shared fact.
    var provesNothing: Bool {
        self == .any || self == .never || decidedAtCall
    }

    // The refusal a cast earns for naming a shape there is nothing to read —
    // nil where the shape names one. Said here, once, because a cast's claim
    // is judged in two places: the declaration scan that sees every cast in
    // every module, and the walk that knows what the value reads as.
    //
    // Each of the three says its own. They are one predicate where only the
    // shared fact is wanted (`provesNothing`), and three sentences here,
    // because a refusal carries its reason: telling an author that `T` names
    // no shape is false — a call names it, elsewhere.
    func unreadableClaim(at location: String) -> String? {
        if self == .any {
            return "\(location): reads as \(rendered), which declares nothing"
                + " — a cast names the shape a value is read as, and `any` is"
                + " the absence of one"
        }

        if self == .never {
            return "\(location): reads as \(rendered), which no value is"
                + " — a cast names the shape a value turns out to have, and"
                + " nothing arrives to have this one"
        }

        if decidedAtCall {
            return "\(location): reads as \(rendered), whose shape the call"
                + " decides — a cast names a shape here, and this one is named"
                + " somewhere else"
        }

        return nil
    }

    // Whether some value could satisfy both shapes at once.
    //
    // Not `accepts`, which asks whether one shape may stand where the other is
    // declared. Two records that name no field in common accept each other in
    // neither direction and are still both satisfied by a value carrying every
    // field: a record says what must be there, not all there is.
    //
    // The bias is deliberate: a refusal is earned only where the shapes
    // provably disagree, and everything else is left to the run. Refusing what
    // this cannot decide would close doors an author has no other way through.
    func couldBothHold(_ other: TypeExpression, in types: TypeTable) -> Bool {
        couldBothHold(other, in: types, assuming: [])
    }

    // Names are peeled one layer at a time, with the pair already being asked
    // about remembered — the guard belongs to *this* walk, because this walk
    // is the one that recurses. Resolving each side whole at every step, as
    // this first did, re-expanded a self-naming type one layer deeper on every
    // descent and never finished: `Tree` holding `array<Tree>` crashed the
    // link, and a guard that lives inside one expansion cannot bound a
    // function that expands again on the way down.
    private func couldBothHold(
        _ other: TypeExpression,
        in types: TypeTable,
        assuming: Set<String>
    ) -> Bool {
        if case let .named(name) = self {
            guard !assuming.contains(name), let declared = types.resolve(name) else { return true }

            return declared.couldBothHold(other, in: types, assuming: assuming.union([name]))
        }

        if case let .named(name) = other {
            guard !assuming.contains(name), let declared = types.resolve(name) else { return true }

            return couldBothHold(declared, in: types, assuming: assuming.union([name]))
        }

        if provesNothing || other.provesNothing { return true }

        // Null is a value both hold, so one exists whatever else they say.
        // Asked of the fact rather than the spelling: `null` and `T?` both
        // hold it and only one of them is written `?`, so reading this off the
        // case would answer for `int?` beside `string?` and not for `int?`
        // beside `null`.
        if declaresNull(in: types), other.declaresNull(in: types) { return true }

        // Two ranges are asked of the judge that decides them, the way
        // `accepts` asks it. The witness below cannot: it carries one value
        // per kind, so a pair peeled to their kinds is a pair of bare kinds
        // and any int answers for both — `int(0...5)` beside `int(10...15)`
        // would come back possible with the bounds already gone. What is
        // provably apart is refused here for the same reason it is refused
        // where it is written, and `overlaps` refuses only that.
        if case let .ranged(mine) = self, case let .ranged(theirs) = other {
            return mine.kind.couldBothHold(theirs.kind, in: types, assuming: assuming)
                && mine.overlaps(theirs)
        }

        // Refinements and compact spellings are dropped first: whether a value
        // could be both is a question about kinds, and `bytes` is an array of
        // bytes however it is spelled.
        switch (unrefined, other.unrefined) {
        case let (.nullable(inner), side), let (side, .nullable(inner)):
            return inner.couldBothHold(side, in: types, assuming: assuming)

        // What both name has to be able to hold at once; what only one names
        // is data the other lets ride through.
        case let (.record(mine), .record(theirs)):
            return mine.allSatisfy { name, field in
                theirs[name].map { field.couldBothHold($0, in: types, assuming: assuming) } ?? true
            }

        // An object and a record are one runtime shape read two ways — the
        // boundary settles both from the same value — so every field the
        // record names must be able to be an entry.
        //
        // A list and a map are not asked about their elements: an empty one is
        // of every element type there is, so `array<string>` and `array<int>`
        // share a value however far apart the elements are, and asking the
        // elements would call a pair impossible that a run settles. The witness
        // below is that empty value, and it answers. A record is asked field by
        // field because the one witness for it holds no fields, so a shape that
        // requires some would have nothing to be judged on.
        case let (.object(entry), .record(fields)), let (.record(fields), .object(entry)):
            return fields.values.allSatisfy { field in
                field.couldBothHold(entry, in: types, assuming: assuming)
            }

        // Two decided kinds, which is where a value either is both or is
        // neither. Anything else this walk does not read into is the run's to
        // answer.
        case let (mine, theirs):
            guard mine.isDecidedKind, theirs.isDecidedKind else { return true }

            // Asked of the judge that will settle it, not of a second opinion
            // about what it would say. One witness per kind is enough here —
            // a decided kind is decided by the value's kind alone, and what a
            // shape says about its parts is the structural cases above — and
            // the pairs that need this are exactly the ones a restatement got
            // wrong: `as double` over an int was refused at the link and
            // settled fine at the run, because the widening lives in
            // `settling` and the restatement had to remember it.
            return TypeExpression.witnesses.contains { witness in
                mine.settles(witness, in: types) && theirs.settles(witness, in: types)
            }
        }
    }

    // One value of every kind a decided shape can hold, for asking the judge
    // rather than restating it. What they carry is empty on purpose: a kind is
    // decided by the value's kind, and everything a shape says about its parts
    // is answered before a witness is reached.
    private static let witnesses: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .object([:]), .bytes([])
    ]

    // Whether this shape takes that value — the boundary's own question, asked
    // where only the answer matters.
    private func settles(_ value: Value, in types: TypeTable) -> Bool {
        (try? settling(value, at: "", in: types)) != nil
    }

    // Whether this names one of the kinds a value simply is, so that two
    // different ones are two things no value is at once.
    private var isDecidedKind: Bool {
        switch self {
        case .bool, .int, .double, .string, .null, .number, .array, .object, .record:
            return true

        default:
            return false
        }
    }

    // The same shape with every name it holds walked through to what that
    // name declares — at every depth, not only the outermost.
    //
    // A name is a spelling, and two spellings of one shape are one shape: a
    // reading of `{ inner: Person }` and a claim of `{ inner: { name: string } }`
    // are the same thing said twice. Resolving only the outermost made that
    // depend on where the author happened to write the name, so the same
    // question got two answers depending on nesting.
    func resolved(in types: TypeTable) -> TypeExpression {
        resolved(in: types, assuming: [])
    }

    // A name already being walked through stands as itself. A type may name
    // itself — `Tree` holding `array<Tree>` is a declared shape — so a walk
    // that expanded every name at every depth would chase one forever. The
    // link refuses *cyclic name chains*, which makes a walk that only follows
    // names finite; this one goes into fields as well, so it is outside that
    // guarantee and carries its own, the way `accepts` does.
    private func resolved(in types: TypeTable, assuming: Set<String>) -> TypeExpression {
        switch self {
        case let .named(name):
            guard !assuming.contains(name), let declared = types.resolve(name) else {
                return self
            }

            return declared.resolved(in: types, assuming: assuming.union([name]))

        case let .array(element):
            return .array(element.resolved(in: types, assuming: assuming))

        case let .object(element):
            return .object(element.resolved(in: types, assuming: assuming))

        case let .nullable(element):
            return .nullable(element.resolved(in: types, assuming: assuming))

        case let .record(fields):
            return .record(fields.mapValues { field in
                field.resolved(in: types, assuming: assuming)
            })

        default:
            return self
        }
    }

    // Whether null is one of this type's values rather than an absence — the
    // fact `T?` exists to declare, and the boundary reads it: a null arriving
    // at a `T?` slot is a value the body takes, not a missing argument.
    //
    // `any` is not this. An undeclared shape accepts a null that arrives, but
    // it does not *spell* null as a value — a required `any` parameter still
    // means "give me something". The looser question, "could a default of
    // null ever be taken", is the link's and includes `any`.
    public func declaresNull(in types: TypeTable) -> Bool {
        switch self {
        case .null, .nullable:
            return true

        case let .named(name):
            return types.resolve(name)?.declaresNull(in: types) ?? false

        default:
            return false
        }
    }
}

extension TypeExpression {
    // Whether a value of `other` may stand where this is declared. Structural,
    // and one-directional: `any` on the left accepts anything because nothing
    // was declared, and `any` on the right is accepted by anything because
    // nothing is known — an undeclared answer cannot be proven wrong.
    //
    // This is the half of checking the linker can do. What a body computes is
    // not readable from the text, but what a *call* answers is: it is the
    // callee's declaration, and a declaration is text.
    public func accepts(_ other: TypeExpression, in types: TypeTable = TypeTable()) -> Bool {
        accepts(other, in: types, assuming: [])
    }

    // The same question, carrying which pairs are already being asked. A named
    // type may reach itself through a shape, so comparing one structurally
    // walks back to the comparison it is inside — and a recursive shape agrees
    // with itself precisely when assuming it does uncovers no disagreement, so
    // a pair met again answers yes rather than asking forever. Only the two
    // `named` doors record the pair, because they are the only way back.
    func accepts(
        _ other: TypeExpression,
        in types: TypeTable,
        assuming: Set<String>
    ) -> Bool {
        switch (self, other) {
        // What answers `never` never arrives, so it cannot be the value that
        // disagrees with a declaration — it fits everywhere. The other way round
        // it fits nowhere, because a slot declaring `never` is a slot nothing
        // can reach.
        case (_, .never):
            return true

        // A type parameter accepts whatever fills it, and what fills it is
        // worked out at the call rather than here — a bounded one included,
        // because membership is judged where the filling is read. In the other
        // direction a parameter stands for some type and this one is that
        // type, so it fits.
        case (.variable, _), (_, .variable), (.reading, _), (_, .reading):
            return true

        case (.any, _), (_, .any):
            return true

        case (.never, _):
            return false

        case (.named(let name), _):
            let pair = "\(name) takes \(other.rendered)"

            guard !assuming.contains(pair) else { return true }
            guard let declared = types.resolve(name) else { return false }

            return declared.accepts(other, in: types, assuming: assuming.union([pair]))

        case (_, .named(let name)):
            let pair = "\(rendered) takes \(name)"

            guard !assuming.contains(pair) else { return true }
            guard let declared = types.resolve(name) else { return false }

            return accepts(declared, in: types, assuming: assuming.union([pair]))

        // A nullable slot takes null, the declared half, and anything nullable
        // whose declared half it takes. The other way round is the refusal the
        // case exists for: what may be null does not stand where null was
        // never declared, so `(_, .nullable)` falls through to disagree.
        case (.nullable, .null):
            return true

        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: types, assuming: assuming)

        case let (.nullable(mine), _):
            return mine.accepts(other, in: types, assuming: assuming)

        case (.array(let mine), .array(let theirs)):
            return mine.accepts(theirs, in: types, assuming: assuming)

        case (.object(let mine), .object(let theirs)):
            return mine.accepts(theirs, in: types, assuming: assuming)

        // A record is an object whose fields happen to be known. What is asked
        // for is a mapping with values of one shape, and a record whose every
        // field is that shape is one — the extra knowledge does not disqualify
        // it. Not the other way round: an `object` promises nothing about which
        // fields exist, and a record names fields it requires.
        case let (.object(mine), .record(theirs)):
            return theirs.values.allSatisfy { field in
                mine.accepts(field, in: types, assuming: assuming)
            }

        // Width again: what stands here must declare at least the fields this
        // one names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.allSatisfy { name, field in
                theirs[name].map { given in
                    field.accepts(given, in: types, assuming: assuming)
                } ?? false
            }

        case let (.procedure(required, wanted), .procedure(given, offered)):
            // A slot asking for purity takes only what says it is pure. The
            // other way round is free: a pure procedure stands anywhere one is
            // wanted, because answering without running is a promise nothing
            // needs relieving of.
            guard wanted != .pure || offered == .pure else { return false }

            // Nothing was said on one side or the other, so nothing is refused.
            guard let required, let given else { return true }

            return required.accepts(given, in: types, assuming: assuming)

        // Two ranges are the one meeting where both sides are the text's
        // fact: the kinds under them decide which way a value may widen, and
        // bounds that cannot overlap are provably apart — refused here the way
        // a range below its own floor is refused where it is written. Any
        // overlap passes; which value arrives is the boundary's to see.
        case let (.ranged(mine), .ranged(theirs)):
            return mine.kind.accepts(theirs.kind, in: types, assuming: assuming)
                && mine.overlaps(theirs)

        // A range against anything else is its kind against that: the bounds
        // speak where a value is settled, and refusing here would need the
        // value. Only what is provably outside is refused before the run.
        case let (.ranged(mine), _):
            return mine.kind.accepts(other, in: types, assuming: assuming)

        case let (_, .ranged(theirs)):
            return accepts(theirs.kind, in: types, assuming: assuming)

        // `bytes` and `array<byte>` are one type in two spellings, so each
        // side reads by its elements: an array slot takes bytes where its
        // element takes a byte, and a bytes slot takes an array whose element
        // type a byte's own range takes.
        case let (.array(mine), .bytes):
            return mine.accepts(.byteElement, in: types, assuming: assuming)

        case let (.bytes, .array(theirs)):
            return TypeExpression.byteElement.accepts(theirs, in: types, assuming: assuming)

        // The one conversion the language has, and it goes the way that cannot
        // lose anything. A slot asking for a whole number does not take a
        // fraction, whatever that fraction happens to be worth.
        case (.double, .int):
            return true

        // A slot that means either takes either.
        case (.number, .int), (.number, .double):
            return true

        // And the other way round, because arithmetic answers one of these and
        // the answer has to fit where a whole number or a fraction was asked
        // for. It reads the same way `any` does one case above: a value known
        // only this loosely fits a slot that takes everything the looseness
        // covers, and no slot that takes less.
        case (_, .number):
            return accepts(.int, in: types, assuming: assuming)
                && accepts(.double, in: types, assuming: assuming)

        default:
            return self == other
        }
    }
}
