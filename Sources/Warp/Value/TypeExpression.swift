//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `ValueType`, which is what a
// value *is*: `any` is only ever something a declaration says, and `array`
// alone was the most a declaration could say about a list. No element, no
// fields, no name for a shape two procedures share.
//
// A type is an expression for the same reason an expression is: it composes.
// `array<string>` is `array` applied to `string`, and a name is a name for one
// of these rather than a separate kind of thing, which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// Checking is structural, and it is width-tolerant on records: a value with
// more fields than the declaration names passes. What arrives here is data from
// outside. A payload gains fields, and a declaration saying which ones it needs
// should not be a declaration that it needs nothing else to exist.
public indirect enum TypeExpression: Sendable, Equatable {
    // Nothing ever *is* `any`. It is what a declaration says when it accepts
    // whatever it is handed. `contains` compares elements of any shape, and
    // declaring `string` there would be a lie the linker would then enforce.
    case any

    // The other end of `any`. No value is ever of this type, which is how a
    // place control does not come back from is written down: a refusal answers
    // `never` because it does not answer at all. Saying so is what keeps the
    // arm that leaves from having an opinion about what the arm that stays
    // holds, without it, one branch failing would cost the other its type.
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
    // means both. Writing `any` there instead said nothing at all, so a sum of
    // a number and a piece of text was found by running it. In a language whose
    // whole claim is that what can be decided before running is.
    //
    // It is not a fourth number. Nothing is ever *of* this type: a value is
    // whole or it is a fraction, and this is what a slot says when either will
    // do. That makes it the numeric `any`, narrowed to the two shapes that
    // arithmetic can actually work with.
    case number

    // A number the slot admits only inside the range. `int(0...255)`,
    // `double(0.0..<1.0)`. The range is the slot's condition, not a new kind:
    // the value is a whole number or a fraction, and the bounds are judged
    // where a value is settled, the way `oneOf` is. At the link for a constant,
    // at the boundary for what only the run can see. A module gives one a name
    // the way it names any type: `byte = int(0...255)`.
    case ranged(Refinement)

    // A list of one shape. The element is always written, so `array<any>` says
    // out loud that anything is accepted. A declaration that accepts anything
    // reads differently from one that has not been written yet.
    case array(TypeExpression)

    // A map of string keys to one shape. A record whose field names are data
    // rather than declaration. Keys are always strings because that is what
    // `Value.record` holds.
    case dictionary(TypeExpression)

    // Named fields with types. The value may carry more.
    case record([Name: TypeExpression])

    // A value that can be called: what it may be called with, and what it must
    // be. Nil is a declaration that has not been written ("some procedure") the
    // way `any` is for a value, and it is accepted by anything for the same
    // reason.
    //
    // Purity and isolation are requirements rather than claims. A declaration
    // never states its own (the linker derives both from what a body does) so
    // what is written here is what a slot asks of whatever fills it.
    case procedure(Signature?, Purity = .unstated, Isolation = .unstated)

    // A field that a path may write through. Only a declared type's field is
    // one: `var int` in a type declaration says a `set` or an `inout` path may
    // pass this field, and a field written without it stops such a path at the
    // link. What the value holds is the inner type; this is a fact about the
    // slot and never about a value.
    case variable(TypeExpression)

    // A parameter the call hands a variable to, in place: the callee writes the
    // caller's box, and the caller reads what was written when the call
    // returns. Only a parameter's type is one. The argument is a path headed by
    // a variable, and what arrives is the inner type.
    case `inout`(TypeExpression)

    // A value that is handed on exactly once. Written on a declared type, so
    // the obligation rides with the name wherever it is mentioned rather than
    // being something a slot could take off.
    //
    // Unlike `var` and `inout` this says nothing about the slot: what it marks
    // is the value, and what it costs is that every body holding one has to
    // give it away on every way through. It is gone by the time anything is
    // lowered, because the whole of it is proven at the link.
    case once(TypeExpression)

    // The declared type, or null. The one union the language has, and it is
    // null-only on purpose. `?.` answers this, and a parameter declaring it may
    // default to null; a general union would put back the "is it this or that"
    // question the whole type system exists to answer once.
    case nullable(TypeExpression)

    // A type a module declared. Kept rather than expanded so that a type may
    // name itself (`Tree` with children of `array<Tree>` is a shape, not a
    // regress) which means resolving one needs the table it was declared in.
    case named(Name)

    // A type parameter, filled by whatever the call site puts there. The name
    // is what ties one signature's mentions together: `first` takes
    // `array<some T>` and answers `some T`, so an array of strings answers a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named`. A name is looked up in a table and this is worked out from the
    // call.
    //
    // The second name bounds it: a parameter bounded by `Comparable` takes only
    // what the constraint by that name admits. The constraint is a declaration
    // like a type (a module binds a name to the types it admits) so a signature
    // writes the name and never the membership, and there is no inline union
    // for the membership to leak out through.
    case parameter(name: Name, constraint: Name? = nil)

    // What a walk *through* a type parameter reached. Still a shape the call
    // decides (a dot on it stands as written, the way a dot on the parameter
    // does) and not the parameter, because a field of an unknown shape is a
    // different unknown. It carries no bound for the same reason: what a
    // constraint admits was proven of the parameter, and nothing was proven of
    // what was read out of it.
    //
    // Apart from `parameter` rather than spelled into one. Both are shapes the
    // link cannot see, but only one of them is a slot a call fills, and the
    // difference has to survive every way a type is built: a declaration is
    // written in a document *and* assembled in a host, and a rule the reader
    // alone enforces is a rule the host walks around. Two cases is that rule
    // stated where nothing can walk around it.
    //
    // The parameter it was read out of, and the path from there, together,
    // because that pair is the whole of what this is. Two walks that land on
    // the same field of the same unknown are one shape, and two fields of it
    // are two.
    //
    // Rooted at the parameter and not at the name a body happened to read
    // through: `of: some T` and `also: some T` are one unknown, so their
    // `.inner` is one field, and a step given a name along the way (`held =
    // of.inner` and then `held.count`) has to arrive where the unbroken walk
    // arrives. A root that was the local name made every naming a new unknown.
    //
    // The path is segments and not their spelling for the same reason: `.a`
    // and `?.a` land on one field, and a spelling would make them two unknowns
    // that never meet.
    case reading(of: Name, path: [PathSegment])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // What this type accepts, settled to the declared representation, or a
    // refusal saying which part disagreed. `at` is the path into the value so
    // the message names the field rather than the whole argument.
    public func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(in: types.shapes).settling(value, at: path(), in: types.shapes)
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

        // The diagnostic voice, not the notation. `rendered` tells an author
        // what a type *is*, and the procedure case below already writes a shape
        // no document spells. So the bound rides along: `some N` alone would
        // hide the one fact a bound refusal is about. What a document spells is
        // the writer's question, and the writer answers it with `bounds`.
        case let .parameter(name, constraint):
            return constraint.map { bound in "some \(name): \(bound)" } ?? "some \(name)"

        // Spelled as what it is. The shape reached by that path. No document
        // writes this, so the spelling answers to the message alone: an author
        // reading a refusal about `item.a` should see where it came from.
        case let .reading(of, path):
            return "some \(([PathSegment.key(of)] + path).rendered)"

        case let .variable(inner):
            return "var \(inner.rendered)"

        case let .inout(inner):
            return "inout \(inner.rendered)"

        case let .once(inner):
            return "once \(inner.rendered)"

        case let .procedure(signature, purity, isolation):
            let word = [
                purity == .pure ? "pure" : nil,
                isolation == .isolated ? "isolated" : nil,
                "procedure"
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let signature else { return word }

            let written = signature.ordered(
                { name, parameter in (name: name, declared: parameter.declared.rendered) },
                standing: { taken in taken.name }
            )
            .map { taken in "\(taken.name): \(taken.declared)" }

            // Rendered as what it accepts, because a message is about what would
            // have fit. Which half was written is a fact about the source rather
            // than about the value being refused.
            return "\(word)<(\(written.joined(separator: ", "))) -> \((signature.returns ?? .any).rendered)>"

        case let .array(element):
            return "array<\(element.rendered)>"

        case let .dictionary(entry):
            return "dictionary<\(entry.rendered)>"

        case let .record(fields):
            let written = fields
                .sorted { left, right in left.key < right.key }
                .map { name, field in "\(name): \(field.rendered)" }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(name):
            return name.spelling

        case let .nullable(inner):
            return "\(inner.rendered)?"
        }
    }

    // MARK: - Private
}

extension TypeExpression: CustomStringConvertible {
    public var description: String { rendered }
}

extension TypeExpression {
    // What one element of bytes is. The range `std` names `byte`. Owned here
    // because the `bytes = array<byte>` equation reads it without a link, so it
    // cannot live behind the name.
    public static let byteElement = TypeExpression.ranged(.whole(from: 0, to: .through(255)))

    // The spelling with its conditions dropped: a range is an int the bounds
    // refine, and bytes are `array<byte>` compacted. This answers the kind
    // question alone. A join asks it, because a join's answer is a kind. It is
    // deliberately not a gate for `accepts` and `settling`: those exist to read
    // exactly what dropping erases. The bounds, and which spelling a slot
    // settles to. The type a parameter hands in place, where it does; otherwise
    // the type itself. What arrives through `inout` is the inner type, and
    // every question about what fits asks that.
    public var inoutUnwrapped: TypeExpression {
        if case let .inout(inner) = self { return inner }
        return self
    }

    public var isInout: Bool {
        if case .inout = self { return true }
        return false
    }

    public var isVariable: Bool {
        if case .variable = self { return true }
        return false
    }

    // The type a field holds, whether or not a path may write through it.
    public var fieldUnwrapped: TypeExpression {
        if case let .variable(inner) = self { return inner }
        return self
    }

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
    // Whether what this stands for is settled at the call. The shallow
    // question, beside `isGeneric`'s deep one. A parameter and a walk through
    // one answer alike, and that is the whole of what is asked: neither is
    // knowable at the link, so a reading that would judge by shape has nothing
    // to judge on. Named for the question and not for one of the two shapes
    // that answer it.
    var decidedAtCall: Bool {
        switch self {
        case .parameter, .reading:
            return true

        default:
            return false
        }
    }

    // Whether this shape proves nothing about the value it holds. The three
    // that stop a walk, named once because they are one question asked twice. A
    // dot needs a shape the types prove, and a cast is the door onto one: what
    // the walk may not read past is exactly what a cast may open, and a cast
    // onto anything else is a claim the types already settled.
    //
    // The three say nothing for three different reasons, and where the reason
    // matters (the sentence a refusal carries) they are asked apart. This is
    // for the places that only need the shared fact.
    var provesNothing: Bool {
        self == .any || self == .never || decidedAtCall
    }

    // The refusal a cast earns for naming a shape there is nothing to read. Nil
    // where the shape names one. Said here, once, because a cast's claim is
    // judged in two places: the declaration scan that sees every cast in every
    // module, and the walk that knows what the value reads as.
    //
    // Each of the three says its own. They are one predicate where only the
    // shared fact is wanted (`provesNothing`), and three sentences here,
    // because a refusal carries its reason: telling an author that `T` names no
    // shape is false. A call names it, elsewhere.
    var unreadableClaim: String? {
        if self == .any {
            return "reads as \(rendered), which declares nothing."
                + " A cast names the shape a value is read as, and `any` is"
                + " the absence of one"
        }

        if self == .never {
            return "reads as \(rendered), which no value is."
                + " A cast names the shape a value turns out to have, and"
                + " nothing arrives to have this one"
        }

        if decidedAtCall {
            return "reads as \(rendered), whose shape the call"
                + " decides. A cast names a shape here, and this one is named"
                + " somewhere else"
        }

        return nil
    }

    // The same shape with every name it holds walked through to what that name
    // declares. At every depth, not only the outermost.
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
    // itself (`Tree` holding `array<Tree>` is a declared shape) so a walk that
    // expanded every name at every depth would chase one forever. The link
    // refuses *cyclic name chains*, which makes a walk that only follows names
    // finite; this one goes into fields as well, so it is outside that
    // guarantee and carries its own, the way `accepts` does.
    private func resolved(in types: TypeTable, assuming: Set<Name>) -> TypeExpression {
        switch self {
        case let .named(name):
            guard !assuming.contains(name), let declared = types.resolve(name) else {
                return self
            }

            return declared.resolved(in: types, assuming: assuming.union([name]))

        case let .array(element):
            return .array(element.resolved(in: types, assuming: assuming))

        case let .dictionary(element):
            return .dictionary(element.resolved(in: types, assuming: assuming))

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

    // Whether null is one of this type's values rather than an absence. The
    // fact `T?` exists to declare, and the boundary reads it: a null arriving
    // at a `T?` slot is a value the body takes, not a missing argument.
    //
    // `any` is not this. An undeclared shape accepts a null that arrives, but
    // it does not *spell* null as a value. A required `any` parameter still
    // means "give me something". The looser question, "could a default of null
    // ever be taken", is the link's and includes `any`.
    public func declaresNull(in types: TypeTable) -> Bool {
        lowered(in: types.shapes).declaresNull(in: types.shapes)
    }
}

extension TypeExpression {
    // Whether a value of `other` may stand where this is declared. Structural,
    // and one-directional: `any` on the left accepts anything because nothing
    // was declared, and `any` on the right is accepted by anything because
    // nothing is known. An undeclared answer cannot be proven wrong.
    //
    // This is the half of checking the linker can do. What a body computes is
    // not readable from the text, but what a *call* answers is: it is the
    // callee's declaration, and a declaration is text.
    public func accepts(_ other: TypeExpression, in types: TypeTable = .empty) -> Bool {
        lowered(in: types.shapes).accepts(other.lowered(in: types.shapes), in: types.shapes)
    }
}
