//
//  Value.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a program computes over. Eight data shapes and one that is not data: a
// procedure is a value here, so a body can be passed, kept and answered with.
//
// The ninth is made by running, never by reading: a closure comes out of the
// expression that writes one, and a program carrying one as a literal is
// refused where a module is made. So a text spells eight, and anything handed
// data from outside a run is handed eight — which is why the writings say so
// where a caller can reach them with the ninth directly.
//
// Equality is written by hand because a procedure has no honest one: two
// procedures are never equal, and identity is not a question this language lets
// you ask.
public indirect enum Value: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case bytes([UInt8])
    case array([Value])

    // Fields under keys, and the name of the declared type the record settled
    // to, where it has. A record made by a literal, answered by a native word
    // or read out of a document has no name; it takes one the first time it
    // settles into a slot that declares a type, and from then on it fits only
    // that name. Two records of one shape under two names are two values.
    case record(name: String?, fields: [String: Value])

    case procedure(Closure)

    // A record with no name: what a literal, a native word and a document
    // make. The one spelling for it, so a caller never writes the nil.
    public static func object(_ fields: [String: Value]) -> Value {
        .record(name: nil, fields: fields)
    }

    // MARK: - Property
    // What is said wherever a value stands where a document can reach it. One
    // sentence because it is one rule, and an author meeting it twice should
    // not have to work out whether they are two.
    public static let procedureIsNotData = "a procedure is not data, so it cannot stand"
        + " where a document reaches — a body a program carries is written as a closure"

    // Whether a procedure is anywhere in here, however deep.
    //
    // The shapes nest, so the question does: a procedure one array inside a
    // record is still a procedure this value holds, and a check that looked
    // only at the outside would pass a program that carries one and refuse the
    // same program written without the wrapper.
    public var holdsProcedure: Bool {
        switch self {
        case .procedure: true
        case let .array(items): items.contains { item in item.holdsProcedure }
        case let .record(_, fields): fields.values.contains { field in field.holdsProcedure }
        default: false
        }
    }

    public var type: ValueType {
        switch self {
        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case .bytes:
            return .bytes

        case .array:
            return .array

        case .record:
            return .object

        case .procedure:
            return .procedure
        }
    }

    // A field of a record, and nil for anything else. Several answers travel as
    // one record because a procedure answers one value, so reading a field back
    // out is the ordinary thing a caller does with what a run gave it.
    public subscript(field: String) -> Value? {
        guard case let .record(_, fields) = self else { return nil }

        return fields[field]
    }

    // The elements a value is indexed by, and nil for what has none. This is
    // where the `bytes = array<byte>` equation lives on the value side: an
    // array answers its own elements and bytes answer theirs as the ints they
    // are — lazily, so a compact spelling is not unpacked to read one element
    // — and a word taking either through `any` reads this one projection
    // instead of knowing the equation itself.
    public var elements: AnyRandomAccessCollection<Value>? {
        switch self {
        case let .array(array):
            return AnyRandomAccessCollection(array)

        case let .bytes(bytes):
            return AnyRandomAccessCollection(bytes.lazy.map { byte in Value.int(Int(byte)) })

        default:
            return nil
        }
    }

    // The elements at these positions, in the spelling this value is — nil for
    // what has no elements to take, the way `elements` answers nil.
    //
    // This is for the words that only put their receiver's own elements in
    // another order or take fewer of them, and so never have to look at one.
    // Saying which by position lets bytes be rearranged as the bytes they are:
    // reading them out as values and writing them back would cost the boxing
    // twice over, which is the cost being compact exists to avoid.
    //
    // A position this value does not have is answered the way a value with no
    // elements at all is: with nil. The three words in this library count
    // their positions from `elements` and so can never ask for one — but this
    // is reachable from outside, where a caller's own arithmetic decides, and
    // a library that brings its caller's process down over that is not one
    // this can be.
    public func elements(at positions: some Sequence<Int>) -> Value? {
        switch self {
        case let .bytes(bytes):
            guard let taken = bytes.taken(at: positions) else { return nil }

            return .bytes(taken)

        case let .array(array):
            guard let taken = array.taken(at: positions) else { return nil }

            return .array(taken)

        default:
            return nil
        }
    }

    // This value with one more element at one end, in the spelling it is — nil
    // for what has no elements, the way the two above answer nil.
    //
    // Only the arriving element is looked at, because it is the only one that
    // can make a compact spelling stop holding: the ones already there are
    // bytes by construction. Reading them out to put one more beside them
    // would spend the whole collection's boxing on a single addition, which is
    // the same waste the two above exist against — and it is the arriving
    // element, not the receiver's size, that decides the answer's spelling.
    public func adding(_ element: Value, atFront: Bool) -> Value? {
        guard let held = elements else { return nil }

        if
            case let .bytes(bytes) = self,
            case let .int(number) = element,
            let byte = UInt8(exactly: number)
        {
            return .bytes(atFront ? [byte] + bytes : bytes + [byte])
        }

        // What arrived is not a byte, or there were none to begin with. Only
        // here is reading the rest out the honest cost of saying what the
        // collection now is, and `respelled` says which spelling that is.
        let elements = Array(held)

        return respelled(atFront ? [element] + elements : elements + [element])
    }

    // These elements, spelled the way this value is. The other half of the
    // projection above: `elements` reads a compact spelling as the array it is,
    // and this writes an array back into the compact spelling where it still
    // holds — so a word that answers its receiver's own elements, rearranged or
    // fewer, answers bytes when it was given bytes.
    //
    // Where it no longer holds — a byte's slot now carrying something that is
    // not one — the answer is a plain array, because the spelling is a fact
    // about the value and saying otherwise would be a claim no value backs.
    //
    // A word that builds *new* elements does not come through here. `map`
    // answers what its procedure answered, and that is its own value however it
    // was reached; the declaration says so by naming a second parameter for it.
    public func respelled(_ elements: some Collection<Value>) -> Value {
        guard case .bytes = self else { return .array(Array(elements)) }

        var bytes = [UInt8]()
        bytes.reserveCapacity(elements.count)

        for element in elements {
            guard
                case let .int(number) = element,
                let byte = UInt8(exactly: number)
            else {
                return .array(Array(elements))
            }

            bytes.append(byte)
        }

        return .bytes(bytes)
    }

    // MARK: - Initializer
    // MARK: - Public
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true

        case let (.bool(left), .bool(right)):
            return left == right

        case let (.int(left), .int(right)):
            return left == right

        case let (.double(left), .double(right)):
            return left == right

        case let (.string(left), .string(right)):
            return left == right

        // Bytes are not text: no encoding is assumed, so equality is the
        // bytes themselves and no Unicode rule applies.
        case let (.bytes(left), .bytes(right)):
            return left == right

        case let (.array(left), .array(right)):
            return left == right

        case let (.record(leftName, left), .record(rightName, right)):
            return leftName == rightName && left == right

        // Two procedures are never equal. Structural equality would compare
        // bodies, which says nothing an author asked about, and reference
        // equality would make a value's identity observable — neither is a
        // question this language has.
        case (.procedure, .procedure):
            return false

        default:
            return false
        }
    }

    // How two values stand to each other, for the kinds that order: numbers
    // among themselves and strings among themselves. Nil is a pair with no
    // order — mixed kinds, the kinds that do not order, and a fraction that
    // is not a number, which orders with nothing. Every consumer of order —
    // equality across numeric width, `lessThan`/`greaterThan`, `sorted`,
    // `min`/`max` — reads this one answer, so a whole beside a fraction is
    // judged in exactly one place.
    public static func order(_ left: Value, _ right: Value) -> ComparisonResult? {
        switch (left, right) {
        case let (.int(first), .int(second)):
            return first == second
                ? .orderedSame
                : first < second ? .orderedAscending : .orderedDescending

        case let (.double(first), .double(second)):
            guard !first.isNaN, !second.isNaN else { return nil }

            return first == second
                ? .orderedSame
                : first < second ? .orderedAscending : .orderedDescending

        case let (.int(first), .double(second)):
            return order(whole: first, fraction: second)

        case let (.double(first), .int(second)):
            return order(whole: second, fraction: first).map { order in
                switch order {
                case .orderedAscending: .orderedDescending
                case .orderedDescending: .orderedAscending
                case .orderedSame: .orderedSame
                }
            }

        case let (.string(first), .string(second)):
            return first == second
                ? .orderedSame
                : first < second ? .orderedAscending : .orderedDescending

        default:
            return nil
        }
    }

    // How a whole number stands against a fraction, exactly at every size.
    // Converting the whole to binary64 rounds above 2^53, and worth must not
    // depend on the rounding — so the fraction is taken apart instead: its
    // whole part meets the int exactly, and only a tie reads what is left.
    private static func order(whole integer: Int, fraction: Double) -> ComparisonResult? {
        guard !fraction.isNaN else { return nil }

        // Past either end of what an int can be — 0x1p63 is the word's own
        // edge, written exactly where `Double(Int.max)` would round past it —
        // the answer needs no digits, and infinity, which only a host can
        // hand in, is answered by the same two lines.
        guard fraction < 0x1p63 else { return .orderedAscending }
        guard fraction >= -0x1p63 else { return .orderedDescending }

        let floored = fraction.rounded(.down)
        let settled = Int(floored)

        guard integer == settled else {
            return integer < settled ? .orderedAscending : .orderedDescending
        }

        // Equal whole parts: whatever the flooring dropped is what the
        // fraction has over the int.
        return fraction == floored ? .orderedSame : .orderedAscending
    }

    // The equality conditions test with — strict except that worth unifies
    // across spellings: int and double across numeric width, and bytes beside
    // an array of what its elements are worth, applied recursively through
    // arrays and objects.
    public func matches(_ other: Value) -> Bool {
        switch (self, other) {
        case (.int, .double), (.double, .int):
            return Value.order(self, other) == .orderedSame

        // Bytes are an array of bytes in a compact spelling — `1` and `1.0`
        // again, one collection up: the worth is the elements', read through
        // the one projection that owns the equation.
        case (.bytes, .array), (.array, .bytes):
            guard let mine = elements, let theirs = other.elements else { return false }

            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.array(left), .array(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.record(leftName, left), .record(rightName, right)):
            return leftName == rightName
                && left.count == right.count
                && left.allSatisfy { key, value in
                    right[key].map { other in value.matches(other) } ?? false
                }

        default:
            return self == other
        }
    }

    // MARK: - Private
}

private extension Array {
    // These positions taken in order, and nil where one of them is not a
    // position this holds — so a caller that counted wrong is answered rather
    // than trapped. Written once for both spellings' storage.
    func taken(at positions: some Sequence<Int>) -> [Element]? {
        var taken = [Element]()

        for position in positions {
            guard indices.contains(position) else { return nil }

            taken.append(self[position])
        }

        return taken
    }
}
