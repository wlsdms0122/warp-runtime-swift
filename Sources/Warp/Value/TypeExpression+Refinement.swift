//
//  TypeExpression+Refinement.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

public extension TypeExpression {
    // The condition a refinement writes on a number.
    //
    // Not a kind of its own. The value is a whole number or a fraction, and
    // this is the slot saying which part of that kind it takes. Judged where
    // any other admission is, at the link for a constant and at the boundary
    // for what only a run can see. A module names one the way it names any type
    // (`byte = int(0...255)`), so the kinds never grow.
    //
    // The two halves are apart because a bound is a value of the kind it
    // bounds. A whole range compares whole numbers exactly and a fraction
    // range compares fractions; one written with the other's bounds would say
    // nothing about any value, and there is no way to write it.
    enum Refinement: Sendable, Equatable {
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
    }
}

public extension TypeExpression.Refinement {
    // What a value has to be before the bounds have anything to say. A range
    // is a condition on a number, and this is which number.
    var kind: TypeExpression {
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

    // What this admits, or why not. The two refusals are different facts (a
    // text where a number was wanted missed the kind, and a number outside the
    // bounds missed the condition) so the boundary can say which.
    enum Settlement: Sendable, Equatable {
        case settled(Value)
        case outside(String)
        case otherKind
    }

    func settling(_ value: Value) -> Settlement {
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

    // Whether the range says anything at all. A slot with neither bound is the
    // kind itself, written the long way.
    var saysNothing: Bool {
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
    var spellable: Bool {
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
    // `double(0.0...)` written out the long way is a range half the fractions
    // are inside. Asking for finiteness here would refuse it.
    var admitsNothing: Bool {
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
    var holdsEveryByte: Bool {
        guard case let .whole(from, to) = self else { return false }

        return Self.holds(0, from: from, to: to) && Self.holds(255, from: from, to: to)
    }

    // Whether ordering this range's bounds answers anything. Said once because
    // two questions lean on it (whether anything is inside, and whether two
    // ranges share a value) and a nan answers no to every comparison, so a
    // question that forgot to ask this would quietly say the opposite of what
    // the other one says.
    var ordersAtAll: Bool {
        switch self {
        // Whole numbers always order.
        case .whole:
            return true

        case let .fraction(from, to):
            return Self.comparable(from) && Self.comparable(to.map(Self.bound))
        }
    }

    // Whether some value is inside both. Asked across kinds as well as within
    // one: a whole number widens into a fraction slot, so `int(0...5)` and
    // `double(0.0...5.0)` are two ranges one value satisfies.
    //
    // Only what is provably apart is refused, which is the bias every judgment
    // before a run takes.
    func overlaps(_ other: Self) -> Bool {
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

    // How the range reads in a document, and in a message: one value, one
    // spelling, because this is written back out and compared as the type's
    // identity.
    var rendered: String {
        // A range with neither bound is the kind itself, so it reads as the
        // kind: one type has one spelling here, and `double(...)` would be a
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

    // MARK: - Private
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
    // answer differently about the same range. `int(..<-9223372036854775808)`
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
    // this vocabulary's words rather than elided. Two ranges are one type when
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

}
