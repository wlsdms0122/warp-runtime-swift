//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `ValueType`, which is what a
// value *is*: `Any` is only ever something a declaration says, and a type
// names an element, fields, or a declared name where a value has none.
//
// A type is an expression for the same reason an expression is: it composes.
// `Array<String>` is `array` applied to `String`, and a name is a name for one
// of these rather than a separate kind of thing, which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// Checking is structural, and it is width-tolerant on records: a value with
// more fields than the declaration names passes. What arrives here is data from
// outside. A payload gains fields, and a declaration saying which ones it needs
// should not be a declaration that it needs nothing else to exist.
public indirect enum TypeExpression: Sendable, Equatable, CustomStringConvertible {
    // Nothing ever *is* `Any`. It is what a declaration says when it accepts
    // whatever it is handed.
    case any

    // The other end of `Any`. No value is ever of this type, which is how a
    // place control does not come back from is written down: a refusal answers
    // `Never` because it does not answer at all. Saying so is what keeps the
    // arm that leaves from having an opinion about what the arm that stays
    // holds, without it, one branch failing would cost the other its type.
    case never

    case null
    case bool
    case int
    case double
    case string

    // A number the slot admits only inside the range. `Int(0...255)`,
    // `Double(0.0..<1.0)`. The range is the slot's condition, not a new kind:
    // the value is a whole number or a fraction, and the bounds are judged
    // where a value is settled, the way `enum` is. At the build for a constant,
    // at the boundary for what only the run can see. A module gives one a name
    // the way it names any type: `byte = int(0...255)`.
    case ranged(Refinement)

    // A list of one type. The element is always written, so `Array<Any>` says
    // out loud that anything is accepted. A declaration that accepts anything
    // reads differently from one that has not been written yet.
    case array(TypeExpression)

    // Names to one type: a record whose field names are data rather than
    // declaration, which a `Value.dictionary` holds.
    case dictionary(TypeExpression)

    // Named fields with types. The value may carry more.
    case record([Name: TypeExpression])

    // A value that can be called: the types it is applied with, in position
    // order, and what it answers. Nil is a declaration that has not been
    // written ("some procedure") the way `Any` is for a value, and it is
    // accepted by anything for the same reason.
    //
    // Constness and isolation are requirements rather than claims. A declaration
    // never states its own (the builder derives both from what a body does) so
    // what is written here is what a slot asks of whatever fills it.
    case procedure(ProcedureType?, Constness = .unstated, Isolation = .unstated)

    // A field that a path may write through. Only a declared type's field is
    // one: `var Int` in a type declaration says a `set` or an `inout` path may
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
    // lowered, because the whole of it is proven at the build.
    case linear(TypeExpression)

    // A parameter that takes the obligation a `linear` value carries. The
    // caller's name is empty afterwards, and this slot is answerable for
    // handing the value on in its turn. Only a parameter's type is one.
    case consuming(TypeExpression)

    // A parameter that reads a `linear` value and leaves the obligation where
    // it was. Nothing is handed over, so the caller still holds the value and
    // still has to hand it on. Only a parameter's type is one.
    //
    // No lifetime rides with this. The language has no references, so what a
    // slot took is a value of its own and cannot outlive what it was read
    // from.
    case borrowing(TypeExpression)

    // The declared type, or null. The one union the language has, and it is
    // null-only on purpose. `?.` answers this; a general union would put back
    // the "is it this or that" question the whole type system exists to
    // answer once.
    case nullable(TypeExpression)

    // A type a module declared. Kept rather than expanded so that a type may
    // name itself (`Tree` with children of `Array<Tree>` is a type, not a
    // regress) which means resolving one needs the table it was declared in.
    case named(Name)

    // A type parameter, filled by whatever the call site puts there. The name
    // is what ties one signature's mentions together: `first` takes
    // `Array<some T>` and answers `some T`, so an array of strings answers a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named`. A name is looked up in a table and this is worked out from the
    // call.
    //
    // The names bound it: a parameter bounded by `Comparable` takes only
    // what the constraint by that name admits, and one bounded by several
    // takes only what every one of them admits or asks. A bound is a
    // declaration like a type (a module binds a name to the types it admits,
    // or to the procedures it asks) so a signature writes the names and never
    // the membership, and there is no inline union for the membership to
    // leak out through. In name order, so one set has one spelling.
    case parameter(name: Name, constraints: [Name] = [])

    // A value of whatever type answers every name here, written `A & B`:
    // the contracts it answers and the memberships it belongs to, with no
    // name of its own to tie one mention to another. One name in this
    // position is written as the name and read as this where the name is a
    // contract's.
    case composition([Name])

    // What a walk *through* a type parameter reached. Still a type the call
    // decides (a dot on it stands as written, the way a dot on the parameter
    // does) and not the parameter, because a field of an unknown type is a
    // different unknown. It carries no bound for the same reason: what a
    // constraint admits was proven of the parameter, and nothing was proven of
    // what was read out of it.
    //
    // Apart from `parameter` rather than spelled into one. Both are types the
    // link cannot see, but only one of them is a slot a call fills, and the
    // difference has to survive every way a type is built: a declaration is
    // written in a document *and* assembled in a host, and a rule the reader
    // alone enforces is a rule the host walks around. Two cases is that rule
    // stated where nothing can walk around it.
    //
    // The parameter it was read out of, and the path from there, together,
    // because that pair is the whole of what this is. Two walks that land on
    // the same field of the same unknown are one type, and two fields of it
    // are two.
    //
    // Rooted at the parameter and not at the name a body happened to read
    // through: `of: some T` and `also: some T` are one unknown, so their
    // `.inner` is one field, and a step given a name along the way (`held =
    // of.inner` and then `held.count`) has to arrive where the unbroken walk
    // arrives.
    //
    // The path is segments and not their spelling for the same reason: `.a`
    // and `?.a` land on one field, and a spelling would make them two unknowns
    // that never meet.
    case projection(of: Name, path: Path)

    // The condition a refinement writes on a number.
    //
    // Not a kind of its own. The value is a whole number or a fraction, and
    // this is the slot saying which part of that kind it takes. Judged where
    // any other admission is, at the build for a constant and at the boundary
    // for what only a run can see. A module names one the way it names any type
    // (`byte = int(0...255)`), so the kinds never grow.
    //
    // The two halves are apart because a bound is a value of the kind it
    // bounds. A whole range compares whole numbers exactly and a fraction
    // range compares fractions; one written with the other's bounds would say
    // nothing about any value, and there is no way to write it.
    public enum Refinement: Sendable, Equatable {
        case whole(from: Int? = nil, to: Edge<Int>? = nil)
        case fraction(from: Double? = nil, to: Edge<Double>? = nil)

        // The far edge of a range, and whether the bound itself is inside it.
        //
        // Only the far edge carries this. `a...b` and `a..<b` are the two
        // intervals programs are actually written against. A position below a
        // length is the second, and for a fraction it is the one nothing can
        // spell by moving a bound. The near edge is always inside, which is the
        // convention every half-open interval is already read by.
        public enum Edge<Bound: Sendable & Equatable & Comparable>: Sendable, Equatable {
            case through(Bound)
            case upTo(Bound)
        }

        // What this admits, or why not. The two refusals are different facts (a
        // text where a number was wanted missed the kind, and a number outside the
        // bounds missed the condition) so the boundary can say which.
        public enum Settlement: Sendable, Equatable {
            case settled(Value)
            case outside(String)
            case otherKind
        }

        // MARK: - Property
        // What a value has to be before the bounds have anything to say. A range
        // is a condition on a number, and this is which number.
        public var kind: TypeExpression {
            switch self {
            case .whole:
                return .int

            case .fraction:
                return .double
            }
        }

        // The same kind as the run reads it.
        internal var lowered: LoweredType {
            switch self {
            case .whole:
                return .int

            case .fraction:
                return .double
            }
        }

        // Whether the range says anything at all. A slot with neither bound is the
        // kind itself, written the long way.
        public var saysNothing: Bool {
            switch self {
            case .whole(nil, nil), .fraction(nil, nil):
                return true

            default:
                return false
            }
        }

        // Whether a document can carry the bounds. Only a fraction's can fail: a
        // whole number's spelling is its digits, and an infinity or a nan is a
        // bound a host's hand put here. The language admits an infinity on purpose,
        // because it orders like any other bound, and no document writes one. Asked
        // by the writer, which may only write what reads back.
        public var spellable: Bool {
            guard case let .fraction(from, to) = self else { return true }

            return (from.map { bound in bound.spelling != nil } ?? true)
                && (to.map { edge in Self.bound(edge).spelling != nil } ?? true)
        }

        // Whether no value is inside. A slot no call could ever fill, which is the
        // declaration refusing itself.
        //
        // A bound that is not a number is one of these and is not caught by
        // comparing: nothing compares to a nan, so a range bounded by one admits
        // nothing while every ordering question about it answers no. A document
        // cannot spell one (a fraction's one spelling is a number) and a
        // declaration assembled in the host can, so it is named here rather than
        // left to the two orderings to imply.
        //
        // An infinity is not one of them. It compares like any other bound, and
        // `Double(0.0...)` written out the long way is a range half the fractions
        // are inside. Asking for finiteness here would refuse it.
        public var admitsNothing: Bool {
            switch self {
            case let .whole(from, to):
                return Self.empty(from: from, to: to, floor: Int.min)

            case let .fraction(from, to):
                guard ordersAtAll else { return true }

                return Self.empty(from: from, to: to, floor: -.infinity)
            }
        }

        // Whether every byte is inside and arrives as itself. The question the
        // compact spelling asks of an element declaration. A fraction range never
        // is: it widens every byte it takes, and a widened byte is not the byte.
        public var holdsEveryByte: Bool {
            guard case let .whole(from, to) = self else { return false }

            return Self.holds(0, from: from, to: to) && Self.holds(255, from: from, to: to)
        }

        // Whether ordering this range's bounds answers anything. Said once because
        // two questions lean on it (whether anything is inside, and whether two
        // ranges share a value) and a nan answers no to every comparison, so a
        // question that forgot to ask this would quietly say the opposite of what
        // the other one says.
        public var ordersAtAll: Bool {
            switch self {
            // Whole numbers always order.
            case .whole:
                return true

            case let .fraction(from, to):
                return Self.comparable(from) && Self.comparable(to.map(Self.bound))
            }
        }

        // How the range reads in a document, and in a message: one value, one
        // spelling, because this is written back out and compared as the type's
        // identity.
        public var rendered: String {
            // A range with neither bound is the kind itself, so it reads as the
            // kind: one type has one spelling here, and `Double(...)` would be a
            // second one for what `saysNothing` already calls the same thing.
            guard !saysNothing else { return kind.rendered }

            switch self {
            case let .whole(from, to):
                let floor = from.map(String.init) ?? ""

                return "\(kind.rendered)(\(floor)\(Self.spelled(to, String.init)))"

            case let .fraction(from, to):
                let floor = Self.fraction(from)

                return "\(kind.rendered)(\(floor)\(Self.spelled(to, Self.fraction)))"
            }
        }

        // The interval as fractions, for the one question two ranges of different
        // kinds share, and for that pair alone: a whole bound past 2^53 arrives as
        // a neighbour, and round-to-nearest-even picks it by the tie, so the edge
        // may move inward as easily as outward. Two ranges of one kind are compared
        // in that kind and never come through here.
        private var span: (lower: Double?, upper: Edge<Double>?) {
            switch self {
            case let .whole(from, to):
                let floor = from.map(Double.init)

                switch to {
                case let .through(bound):
                    return (floor, .through(Double(bound)))

                case let .upTo(bound):
                    return (floor, .upTo(Double(bound)))

                case nil:
                    return (floor, nil)
                }

            case let .fraction(from, to):
                return (from, to)
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        public func settling(_ value: Value) -> Settlement {
            switch self {
            case let .whole(from, to):
                guard case let .int(number) = value else { return .otherKind }

                return Self.holds(number, from: from, to: to)
                    ? .settled(value)
                    : .outside(String(number))

            // A whole number arrives at a fraction slot as the fraction it widens
            // to, which is the one conversion the language has, so the bounds judge
            // what the slot would hold rather than what was written.
            case let .fraction(from, to):
                guard let number = Self.fraction(of: value) else { return .otherKind }

                guard Self.holds(number, from: from, to: to) else {
                    return .outside(number.shown)
                }

                return .settled(.double(number))
            }
        }

        // Whether some value is inside both. Asked across kinds as well as within
        // one: a whole number widens into a fraction slot, so `Int(0...5)` and
        // `Double(0.0...5.0)` are two ranges one value satisfies.
        //
        // Only what is provably apart is refused, which is the bias every judgment
        // before a run takes.
        public func overlaps(_ other: Self) -> Bool {
            guard ordersAtAll, other.ordersAtAll else { return false }

            // Two whole ranges are compared as whole numbers. Widening is what the
            // question across kinds needs, and it is not free: past 2^53 a whole
            // number arrives as a neighbour, and which neighbour depends on the
            // tie, so two ranges that share a value up there can come out apart.
            // Nothing has to be widened to compare two of the same kind.
            if case let .whole(myFloor, myCeiling) = self,
                case let .whole(theirFloor, theirCeiling) = other {
                return Self.meeting(
                    (myFloor, myCeiling),
                    (theirFloor, theirCeiling),
                    floor: Int.min
                )
            }

            return Self.meeting(span, other.span, floor: -.infinity)
        }

        // MARK: - Private
        // Whether two intervals of one kind have anything between them. Said once,
        // for the pair compared as whole numbers and the pair compared as fractions
        // alike.
        private static func meeting<Bound>(
            _ mine: (lower: Bound?, upper: Edge<Bound>?),
            _ theirs: (lower: Bound?, upper: Edge<Bound>?),
            floor: Bound
        ) -> Bool {
            if let upper = mine.upper,
                empty(from: theirs.lower, to: upper, floor: floor) { return false }
            if let upper = theirs.upper,
                empty(from: mine.lower, to: upper, floor: floor) { return false }

            return true
        }

        // Whether ordering this bound answers anything. Not whether it is finite:
        // an infinity orders, a nan does not.
        private static func comparable(_ bound: Double?) -> Bool {
            bound.map { bound in !bound.isNaN } ?? true
        }

        private static func bound(_ edge: Edge<Double>) -> Double {
            switch edge {
            case let .through(bound), let .upTo(bound):
                return bound
            }
        }

        private static func fraction(of value: Value) -> Double? {
            switch value {
            case let .double(fraction):
                return fraction

            case let .int(whole):
                return Double(whole)

            default:
                return nil
            }
        }

        private static func holds<Bound>(
            _ number: Bound,
            from: Bound?,
            to: Edge<Bound>?
        ) -> Bool {
            if let from, number < from { return false }

            switch to {
            case let .through(bound):
                return number <= bound

            case let .upTo(bound):
                return number < bound

            case nil:
                return true
            }
        }

        // Whether nothing is between the bounds. A range with no floor stands on
        // the kind's own, because that is what the floor means: `holds` reads a
        // missing floor as open downward and answers against every value the kind
        // has, so a question about emptiness that read it as "cannot say" would
        // answer differently about the same range. `Int(..<-9223372036854775808)`
        // is a slot no call could fill, and it is spellable.
        private static func empty<Bound>(
            from: Bound?,
            to: Edge<Bound>?,
            floor: Bound
        ) -> Bool {
            let from = from ?? floor

            switch to {
            case let .through(bound):
                return bound < from

            // The bound itself is outside, so a floor standing on it leaves
            // nothing between them.
            case let .upTo(bound):
                return bound <= from

            case nil:
                return false
            }
        }

        // A fraction as a range writes it. A bound no document spells is shown in
        // this vocabulary's own terms rather than elided. Two ranges are one type when
        // they hold the same numbers, and dropping an unspellable bound would read
        // a bounded range and an unbounded one alike. What comes out then is for a
        // message; `spellable` is what the writer asks.
        private static func fraction(_ bound: Double?) -> String {
            guard let bound else { return "" }

            return bound.shown
        }

        private static func spelled<Bound>(
            _ to: Edge<Bound>?,
            _ spelling: (Bound) -> String
        ) -> String {
            switch to {
            case let .through(bound):
                return "...\(spelling(bound))"

            case let .upTo(bound):
                return "..<\(spelling(bound))"

            case nil:
                return "..."
            }
        }
    }

    // MARK: - Property
    // The types the language names, by the spelling a document writes each
    // under. A spelling here is never a declaration's: what a document
    // declares stands beside these, and a reader answers one of these before
    // it looks for a declaration.
    public static let keywords: [Name: TypeExpression] = [
        "Any": .any,
        // A declaration a call never comes back from. Written out loud because
        // a procedure that always refuses is a procedure an author may declare.
        "Never": .never,
        "Null": .null,
        "Bool": .bool,
        "Int": .int,
        "Double": .double,
        "String": .string,
        "Procedure": .procedure(nil)
    ]

    // The types the language names that a value is an instance of, under
    // the name a claim writes and `Value.nominal` answers, each as the type
    // a claim about it stands for. A list and a map are named bare: every
    // list is a list whatever it holds, and a value does not say which
    // elements a slot declared it to hold.
    public static let nominalTypes: [Name: TypeExpression] = [
        "Bool": .bool,
        "Int": .int,
        "Double": .double,
        "String": .string,
        "Array": .array(.any),
        "Dictionary": .dictionary(.any)
    ]

    // What one element of bytes is. The range `Standard` names `Standard.Byte`. Owned here
    // because the `bytes = Array<Standard.Byte>` equation reads it without a table, so it
    // cannot live behind the name.
    public static let byteElement = TypeExpression.ranged(.whole(from: 0, to: .through(255)))

    // Bytes are an array of that element. What a procedure the host answers
    // declares, without a link to name the range through.
    public static let bytes = TypeExpression.array(.byteElement)

    // How the type reads in a message. A declaration an author wrote should come
    // back to them in the spelling they wrote it in.
    public var rendered: String {
        switch self {
        case .any:
            return "Any"

        case .never:
            return "Never"

        case .null:
            return "Null"

        case .bool:
            return "Bool"

        case .int:
            return "Int"

        case .double:
            return "Double"

        case .string:
            return "String"

        case let .ranged(refinement):
            // The exact spelling: what is rendered here is written into
            // documents and compared as the type's identity, not a message.
            return refinement.rendered

        // The diagnostic voice, not the notation. `rendered` tells an author
        // what a type *is*, and the procedure case below already writes a type
        // no document spells. So the bound rides along: `some N` alone would
        // hide the one fact a bound refusal is about. What a document spells is
        // the writer's question, and the writer answers it with `bounds`.
        case let .parameter(name, constraints):
            return constraints.isEmpty
                ? "some \(name)"
                : "some \(name): \(constraints.map(\.spelling).joined(separator: " & "))"

        case let .composition(names):
            return names.map(\.spelling).joined(separator: " & ")

        // Spelled as what it is. The type reached by that path. No document
        // writes this, so the spelling answers to the message alone: an author
        // reading a refusal about `item.a` should see where it came from.
        case let .projection(of, path):
            return "some \(Path([.key(of)] + path.segments).rendered)"

        case let .variable(inner):
            return "var \(inner.rendered)"

        case let .inout(inner):
            return "inout \(inner.rendered)"

        case let .linear(inner):
            return "linear \(inner.rendered)"

        case let .consuming(inner):
            return "consuming \(inner.rendered)"

        case let .borrowing(inner):
            return "borrowing \(inner.rendered)"

        case let .procedure(type, constness, isolation):
            let spelling = [
                constness == .const ? "const" : nil,
                isolation == .isolated ? "isolated" : nil,
                "Procedure"
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let type else { return spelling }

            let written = type.parameters.map(\.rendered)

            // Rendered as what it accepts, because a message is about what would
            // have fit. Which half was written is a fact about the source rather
            // than about the value being refused.
            return "\(spelling)<(\(written.joined(separator: ", ")))"
                + " -> \((type.returns ?? .any).rendered)>"

        case let .array(element):
            return "Array<\(element.rendered)>"

        case let .dictionary(entry):
            return "Dictionary<\(entry.rendered)>"

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

    var unrefined: TypeExpression {
        switch self {
        case let .ranged(refinement):
            return refinement.kind

        default:
            return self
        }
    }

    // The refusal a cast earns for naming a type there is nothing to read. Nil
    // where the type names one. Said here, once, because a cast's claim is
    // judged in two places: the declaration scan that sees every cast in every
    // module, and the walk that knows what the value reads as.
    //
    // Each of the three says its own, because a refusal carries its reason:
    // telling an author that `T` names no type is false. A call names it,
    // elsewhere. A type parameter anywhere in the claim is the third, since
    // nothing in a body fills it and the run would settle what arrived against
    // no type there.
    var unreadableClaim: String? {
        if self == .any {
            return "reads as \(rendered), which declares nothing."
                + " A cast names the type a value is read as, and `Any` is"
                + " the absence of one"
        }

        if self == .never {
            return "reads as \(rendered), which no value is."
                + " A cast names the type a value turns out to have, and"
                + " nothing arrives to have this one"
        }

        if isGeneric {
            return "reads as \(rendered), whose type the call"
                + " decides. A cast names a type here, and this one is named"
                + " somewhere else"
        }

        return nil
    }

    // Every declared name this reaches: the types it names, and the
    // memberships it bounds a parameter by.
    //
    // A parameter's own name is not one of them. It stands for a type the
    // call decides rather than one a module declared, and what a walk through
    // one reached is rooted at that same undeclared type.
    var mentions: Set<Name> {
        switch self {
        case .any, .never, .null, .bool, .int, .double, .string, .ranged:
            []

        case let .array(element):
            element.mentions

        case let .dictionary(entry):
            entry.mentions

        case let .record(fields):
            fields.values.reduce(into: Set()) { mentioned, field in
                mentioned.formUnion(field.mentions)
            }

        case let .procedure(type, _, _):
            type?.mentions ?? []

        case let .variable(inner), let .inout(inner), let .linear(inner), let .nullable(inner),
            let .consuming(inner), let .borrowing(inner):
            inner.mentions

        case let .named(name):
            [name]

        case let .parameter(_, constraints):
            Set(constraints)

        case let .composition(names):
            Set(names)

        case .projection:
            []
        }
    }

    // Every type parameter mentioned in here, occurrence by occurrence, each
    // with the bounds it carries.
    var parameterOccurrences: [ParameterOccurrence] {
        switch self {
        case let .parameter(name, constraints):
            return [ParameterOccurrence(name: name, constraints: constraints)]

        case .projection, .composition:
            return []

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            return element.parameterOccurrences

        case let .record(fields):
            return fields.values.flatMap { field in field.parameterOccurrences }

        case let .procedure(type, _, _):
            return type?.parameterOccurrences ?? []

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner.parameterOccurrences

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named:
            return []
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read the way it always was, so nothing pays for a feature it does not
    // use.
    var isGeneric: Bool {
        switch self {
        // Both are types a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .projection:
            return true

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(type, _, _):
            return type?.isGeneric ?? false

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named, .composition:
            return false
        }
    }

    // The type a slot's mark stands in front of, where it has one, and the type
    // itself otherwise. What arrives through `inout`, `consuming` or
    // `borrowing` is the inner type, and every question about what fits asks
    // that.
    //
    // No `default`: a mark nobody thought about must be a compile error here
    // rather than an answer of "no mark".
    public var slotUnwrapped: TypeExpression {
        switch self {
        case let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .variable, .linear,
            .nullable, .named, .parameter, .projection, .composition:
            return self
        }
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
        switch self {
        case let .variable(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .inout, .linear,
            .consuming, .borrowing, .nullable, .named, .parameter, .projection, .composition:
            return self
        }
    }

    public var description: String { rendered }

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
        try lowered(in: types.loweredTypes).settling(value, at: path(), in: types.loweredTypes)
    }

    // The same type with every name it holds walked through to what that name
    // declares. At every depth, not only the outermost.
    //
    // A name is a spelling, and two spellings of one type are one type: a
    // reading of `{ inner: Person }` and a claim of `{ inner: { name: string } }`
    // are the same thing said twice. Resolving only the outermost made that
    // depend on where the author happened to write the name, so the same
    // question got two answers depending on nesting.
    func resolved(in types: TypeTable) -> TypeExpression {
        resolved(in: types, assuming: [])
    }

    // The occurrence side of `Signature.bounded(by:)`, walked through every
    // place a type parameter may sit. A nested procedure type's parameters
    // included, because they are the outer signature's own slots.
    func bounded(by bounds: [Name: [Name]]) -> TypeExpression {
        switch self {
        case let .parameter(name, constraints):
            return .parameter(name: name, constraints: constraints.isEmpty ? bounds[name] ?? [] : constraints)

        case .projection, .composition:
            return self

        case let .linear(inner):
            return .linear(inner.bounded(by: bounds))

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(type, constness, isolation):
            return .procedure(type?.bounded(by: bounds), constness, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case let .consuming(inner):
            return .consuming(inner.bounded(by: bounds))

        case let .borrowing(inner):
            return .borrowing(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named:
            return self
        }
    }

    // Whether null is one of this type's values. The fact `T?` exists to
    // declare.
    //
    // `Any` is not this. An undeclared type accepts a null that arrives, but
    // it does not *spell* null as a value. The looser question, "does a null
    // that arrives pass", is `admitsNull` and includes `Any`.
    public func declaresNull(in types: TypeTable) -> Bool {
        lowered(in: types.loweredTypes).declaresNull(in: types.loweredTypes)
    }

    // Whether a value of `other` may stand where this is declared. Structural,
    // and one-directional: `Any` on the left accepts anything because nothing
    // was declared, and `Any` on the right is accepted by anything because
    // nothing is known. An undeclared answer cannot be proven wrong.
    //
    // This is the half of checking the builder can do. What a body computes is
    // not readable from the text, but what a *call* answers is: it is the
    // callee's declaration, and a declaration is text.
    public func accepts(_ other: TypeExpression, in types: TypeTable = .empty) -> Bool {
        lowered(in: types.loweredTypes).accepts(other.lowered(in: types.loweredTypes), in: types.loweredTypes)
    }

    // Whether values of this type are handed on once, through the names it may
    // hide behind. The one door: what the walk below could not decide is folded
    // to "not one" here and nowhere inside it, so the answer does not depend on
    // how many wrappers a type was written under.
    func handedOnce(in table: TypeTable) -> Bool {
        Self.reaches(self, in: table, assuming: []) ?? false
    }

    // MARK: - Private
    // A name already being walked through stands as itself. A type may name
    // itself (`Tree` holding `Array<Tree>` is a declared type) so a walk that
    // expanded every name at every depth would chase one forever. The link
    // refuses *cyclic name chains*, which makes a walk that only follows names
    // finite; this one goes into fields as well, so it is outside that
    // guarantee and carries its own, the way `accepts` does.
    private func resolved(in types: TypeTable, assuming: Set<Name>) -> TypeExpression {
        switch self {
        case let .named(name):
            guard !assuming.contains(name), let declared = types.types[name] else {
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

    // The same question, answering nil where the walk only ever came back to a
    // membership it was already inside. A cycle says nothing new, so a cycle of
    // nothing else says nothing at all, and folding that to "not one" is done
    // at the one door above rather than partway down: fold it inside the
    // recursion and the answer starts depending on how many wrappers a member
    // was written under.
    //
    // No `default`: a type nobody thought about must be a compile error here
    // rather than an answer of no.
    private static func reaches(
        _ type: TypeExpression,
        in table: TypeTable,
        assuming: Set<Name>
    ) -> Bool? {
        switch type {
        case .linear:
            return true

        case let .named(name):
            if let declared = table.types[name] {
                return reaches(declared, in: table, assuming: assuming)
            }

            return reaches(membership: name, in: table, assuming: assuming)

        // A parameter bounded by a membership stands for some member of it, so
        // what every member is, it is. An unbounded one stands for whatever the
        // call put there, which the build never wrote down. A composition
        // stands for a member of every membership it names.
        case let .parameter(_, bounds), let .composition(bounds):
            let answers = bounds.compactMap { bound in reaches(membership: bound, in: table, assuming: assuming) }

            return answers.isEmpty ? nil : answers.contains(true)

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return reaches(inner, in: table, assuming: assuming)

        // A nullable of one is refused where it is written, because "hand it on
        // if it is there" is not something this language says. So nothing is
        // one behind a `?`.
        case .nullable:
            return false

        // None of these is one, and none of them carries one: a value handed on
        // once is followed by the name that holds it, and a name does not go
        // into a type.
        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .projection:
            return false
        }
    }

    // A membership is one when every member is. A membership this question is
    // already inside is taken as it stood rather than asked again, which is
    // what every other question about a membership does here, and one that
    // reached no member of its own answers nothing at all.
    private static func reaches(
        membership name: Name,
        in table: TypeTable,
        assuming: Set<Name>
    ) -> Bool? {
        guard !assuming.contains(name) else { return nil }

        guard let members = table.constraints[name], !members.isEmpty else { return false }

        let answers = members.compactMap { member in
            reaches(member, in: table, assuming: assuming.union([name]))
        }

        guard !answers.isEmpty else { return nil }

        return answers.allSatisfy { answer in answer }
    }
}
