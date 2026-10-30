//
//  Value.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a program computes over: data, and one kind that is not data. A
// procedure is a value here, so a body can be passed, kept and returned.
//
// A procedure is made by running, never by reading: a closure comes out of
// the expression that writes one, and a program carrying one as a literal is
// refused where a module is made. So a text spells data alone, and anything
// handed data from outside a run is handed data alone, which is why the
// writings say so where a caller can reach them with a procedure directly.
//
// Equality is strict, kind and spelling included, and written by hand: two
// procedures are never equal, since identity is not a question this language
// lets you ask.
public indirect enum Value: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case bytes([UInt8])
    case array([Value])

    // Fields under names, and the name of the declared struct it is a value
    // of. Two structs of one structure under two names are two values.
    case `struct`(Struct)

    // Entries under keys that are values: what a document's mappings are,
    // what a host builds out of raw data, and what a dictionary literal makes. A dictionary
    // is never a struct.
    case dictionary(Dictionary)

    case procedure(Closure)

    // A value read as a contract, beside the type it was read as. Only a run
    // makes one, and every reading of a value as data reads what it holds.
    case existential(Existential)

    // Entries under keys that are values. They stand in the key order, the
    // order the canonical writing and `keys` walk a dictionary in, and a key is found
    // by that order and then by sameness, so two keys that are the same value
    // are one key: `1` and `1.0`, two spellings of one string, bytes and the
    // array of their numbers. A key that is the same as no value, a `Double`
    // that is not a number or one holding a procedure, is never found again.
    public struct Dictionary: Sendable, Equatable {
        // MARK: - Property
        // In ascending key order, no key the same as another.
        public let entries: [(key: Value, value: Value)]

        public var keys: [Value] {
            entries.map(\.key)
        }

        public var values: [Value] {
            entries.map(\.value)
        }

        public var count: Int {
            entries.count
        }

        public var isEmpty: Bool {
            entries.isEmpty
        }

        // MARK: - Initializer
        // Entries in any order under keys none of which is the same as
        // another.
        public init(_ entries: [(key: Value, value: Value)]) throws {
            let sorted = entries.sorted { one, other in Self.order(one.key, other.key) == .orderedAscending }

            if let repeated = zip(sorted, sorted.dropFirst()).first(where: { one, other in one.key.matches(other.key) }) {
                throw ValueRefused("'\(Rendering(repeated.0.key).text())' is written twice")
            }

            self.entries = sorted
        }

        // A dictionary keyed by strings, the way a document's mappings are keyed by
        // the names it writes.
        public init(_ fields: [Name: Value]) {
            self.entries = fields
                .map { field in (key: Value.string(field.key.spelling), value: field.value) }
                .sorted { one, other in Self.order(one.key, other.key) == .orderedAscending }
        }

        // Entries already in the key order, under keys none of which is the
        // same as another, where the maker holds both facts itself. An
        // object's list of entries carries both once its reading judged the
        // order, so what stands on it comes through here rather than being
        // sorted again. Entries with neither behind them come through the
        // initializer above.
        init(ordered entries: [(key: Value, value: Value)]) {
            self.entries = entries
        }

        // MARK: - Public
        public subscript(key key: Value) -> Value? {
            let (position, found) = place(of: key)

            return found ? entries[position].value : nil
        }

        // The entry under a string key, the way a document's mapping is read
        // by a name.
        public subscript(name: Name) -> Value? {
            self[key: .string(name.spelling)]
        }

        // The entries under the names their keys are, in the same order: how
        // a document's mapping, keyed by the names it writes, is read. A key
        // that is no name is refused.
        public func named() throws -> [(name: Name, value: Value)] {
            try entries.map { entry in
                guard case let .string(text) = entry.key, let name = try? Name(text) else {
                    throw ValueRefused("'\(Rendering(entry.key).text())' is no name, and a mapping a document writes is keyed by names")
                }

                return (name: name, value: entry.value)
            }
        }

        // This dictionary with one entry written: the value replaced where the key is
        // held, and the entry put where it orders where it is not.
        public func writing(key: Value, with value: Value) -> Dictionary {
            var written = entries
            let (position, found) = place(of: key)

            if found {
                written[position].value = value
            } else {
                written.insert((key: key, value: value), at: position)
            }

            return Dictionary(ordered: written)
        }

        // The same under a string key.
        public func writing(_ name: Name, with value: Value) -> Dictionary {
            writing(key: .string(name.spelling), with: value)
        }

        // This dictionary without the entry under this key, or as it is where none
        // is held.
        public func removing(key: Value) -> Dictionary {
            let (position, found) = place(of: key)

            guard found else { return self }

            var written = entries
            written.remove(at: position)

            return Dictionary(ordered: written)
        }

        // The same under a string key.
        public func removing(_ name: Name) -> Dictionary {
            removing(key: .string(name.spelling))
        }

        // This dictionary with every value put through `transform`, under the same
        // keys in the same order.
        public func mapValues(_ transform: (Value, Value) throws -> Value) rethrows -> Dictionary {
            Dictionary(
                ordered: try entries.map { entry in (key: entry.key, value: try transform(entry.key, entry.value)) }
            )
        }

        public static func == (lhs: Dictionary, rhs: Dictionary) -> Bool {
            lhs.entries.count == rhs.entries.count
                && zip(lhs.entries, rhs.entries).allSatisfy { mine, theirs in
                    mine.key == theirs.key && mine.value == theirs.value
                }
        }

        // How two keys stand in the key order: by kind first (null, bool,
        // number, string, list, dictionary, struct, and a procedure last), then false
        // before true, numbers by worth, a string as `String` orders it, which
        // is its scalars in normal form C, lists element by element with a
        // shorter one first on a common start, dictionaries entry by entry, and
        // structs by name and then field by field. Bytes are the list of
        // their numbers. Two keys the same value stand at one place; a
        // `Double` that is not a number stands after every number, and a
        // procedure after everything, each at one place it shares with its
        // own kind and is the same as nothing there.
        public static func order(_ left: Value, _ right: Value) -> ComparisonResult {
            if case let .existential(mine) = left {
                return order(mine.value, right)
            }

            if case let .existential(theirs) = right {
                return order(left, theirs.value)
            }

            let ranks = (rank(of: left), rank(of: right))

            guard ranks.0 == ranks.1 else { return ranks.0 < ranks.1 ? .orderedAscending : .orderedDescending }

            switch (left, right) {
            case let (.bool(mine), .bool(theirs)):
                return mine == theirs ? .orderedSame : (theirs ? .orderedAscending : .orderedDescending)

            case (.int, _), (.double, _):
                return worth(left, right)

            case let (.string(mine), .string(theirs)):
                return mine == theirs ? .orderedSame : (mine < theirs ? .orderedAscending : .orderedDescending)

            case let (.dictionary(mine), .dictionary(theirs)):
                return sequenced(
                    mine.entries.lazy.flatMap { entry in [entry.key, entry.value] },
                    theirs.entries.lazy.flatMap { entry in [entry.key, entry.value] }
                )

            case let (.struct(mine), .struct(theirs)):
                guard mine.name == theirs.name else {
                    return mine.name < theirs.name ? .orderedAscending : .orderedDescending
                }

                return sequenced(
                    zip(mine.names, mine.values).lazy.flatMap { name, value in [Value.string(name.spelling), value] },
                    zip(theirs.names, theirs.values).lazy.flatMap { name, value in [Value.string(name.spelling), value] }
                )

            default:
                guard let mine = left.elements, let theirs = right.elements else { return .orderedSame }

                return sequenced(mine, theirs)
            }
        }

        // MARK: - Private
        // Where a key is, or where it would go: the first position whose key
        // does not precede it, and whether the key there is it.
        private func place(of key: Value) -> (Int, Bool) {
            var low = 0
            var high = entries.count

            while low < high {
                let middle = (low + high) / 2

                if Self.order(entries[middle].key, key) == .orderedAscending {
                    low = middle + 1
                } else {
                    high = middle
                }
            }

            return (low, low < entries.count && entries[low].key.matches(key))
        }

        // Where a kind stands in the key order.
        private static func rank(of value: Value) -> Int {
            switch value {
            case .null: 0
            case .bool: 1
            case .int, .double: 2
            case .string: 3
            case .array, .bytes: 4
            case .dictionary: 5
            case .struct: 6
            case .procedure: 7
            case let .existential(existential): rank(of: existential.value)
            }
        }

        // Two numbers by what they are worth, exactly: an `Int` and a
        // `Double` are compared without converting the `Int`, which
        // would round past 2^53. A `Double` that is not a number stands after
        // every number.
        private static func worth(_ left: Value, _ right: Value) -> ComparisonResult {
            switch (left, right) {
            case let (.int(mine), .int(theirs)):
                return mine == theirs ? .orderedSame : (mine < theirs ? .orderedAscending : .orderedDescending)

            case let (.double(mine), .double(theirs)):
                if mine.isNaN || theirs.isNaN {
                    return mine.isNaN == theirs.isNaN ? .orderedSame : (theirs.isNaN ? .orderedAscending : .orderedDescending)
                }

                return mine == theirs ? .orderedSame : (mine < theirs ? .orderedAscending : .orderedDescending)

            case let (.int(integer), .double(double)):
                return worth(integer: integer, double: double)

            case let (.double(double), .int(integer)):
                switch worth(integer: integer, double: double) {
                case .orderedAscending: return .orderedDescending
                case .orderedDescending: return .orderedAscending
                case .orderedSame: return .orderedSame
                }

            default:
                return .orderedSame
            }
        }

        // An `Int` against a `Double`: ascending where the `Int` is worth
        // less.
        private static func worth(integer: Int, double: Double) -> ComparisonResult {
            guard !double.isNaN else { return .orderedAscending }
            guard double >= -0x1p63 else { return .orderedDescending }
            guard double < 0x1p63 else { return .orderedAscending }

            let floor = double.rounded(.down)
            let truncated = Int(floor)

            if integer < truncated { return .orderedAscending }
            if integer > truncated { return .orderedDescending }

            return floor == double ? .orderedSame : .orderedAscending
        }

        // Two sequences of keys element by element, a shorter one first on a
        // common start.
        private static func sequenced(_ left: some Sequence<Value>, _ right: some Sequence<Value>) -> ComparisonResult {
            var mine = left.makeIterator()
            var theirs = right.makeIterator()

            while true {
                switch (mine.next(), theirs.next()) {
                case (nil, nil):
                    return .orderedSame

                case (nil, _):
                    return .orderedAscending

                case (_, nil):
                    return .orderedDescending

                case let (one?, other?):
                    let ordered = order(one, other)

                    guard ordered == .orderedSame else { return ordered }
                }
            }
        }
    }

    // MARK: - Property
    // How deep a written tree may nest: a document, and every tree an object
    // writes as the entries of a table. The bound is exact: a reading takes a
    // tree within it and refuses the first level past it.
    public static let nestingBound = 128

    // What is said wherever a value stands where a document can reach it.
    static let procedureIsNotData = "a procedure is not data, so it cannot stand"
        + " where a document reaches; a body a program carries is written as a closure"

    // Whether a procedure is anywhere in here, however deep.
    //
    // The types nest, so the question does: a procedure one array inside a
    // struct is still a procedure this value holds, and a check that looked
    // only at the outside would pass a program that carries one and refuse the
    // same program written without the wrapper.
    public var holdsProcedure: Bool {
        holdsClosure { _ in true }
    }

    // Whether a `Double` with no finite value is anywhere in here, however
    // deep: a value no document and no encoding carries.
    var holdsNonFiniteNumber: Bool {
        switch self {
        case let .double(number):
            return !number.isFinite

        case .null, .bool, .int, .string, .bytes, .procedure:
            return false

        case let .array(elements):
            return elements.contains { element in element.holdsNonFiniteNumber }

        case let .dictionary(held):
            return held.entries.contains { key, value in key.holdsNonFiniteNumber || value.holdsNonFiniteNumber }

        case let .struct(instance):
            return instance.values.contains { field in field.holdsNonFiniteNumber }

        case let .existential(existential):
            return existential.value.holdsNonFiniteNumber
        }
    }

    // Whether a struct is anywhere in here, however deep. A struct is the
    // value of a declared struct, made where a literal is written into one or
    // handed through a door under the struct's name.
    var holdsStruct: Bool {
        switch self {
        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return false

        case let .array(elements):
            return elements.contains { element in element.holdsStruct }

        case let .dictionary(held):
            return held.entries.contains { key, value in key.holdsStruct || value.holdsStruct }

        case .struct:
            return true

        case let .existential(existential):
            return existential.value.holdsStruct
        }
    }

    // The elements a value is indexed by, and nil for what has none. This is
    // where the `bytes = Array<Int>` equation lives on the value side: an
    // array returns its own elements and bytes return theirs as the ints they
    // are, lazily, so a compact spelling is not unpacked to read one element,
    // and a procedure taking either through `Any` reads these elements
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

    // The bytes a value is, in either spelling: the compact one as it is, and
    // an array of integers inside a byte's range read out one by one.
    // Nil for anything else. The other half of the equation `elements`
    // holds, for a procedure that wants the bytes rather than an element.
    public var bytes: [UInt8]? {
        switch self {
        case let .bytes(bytes):
            return bytes

        case let .array(elements):
            var bytes: [UInt8] = []
            bytes.reserveCapacity(elements.count)

            for element in elements {
                guard case let .int(number) = element, let byte = UInt8(exactly: number) else { return nil }

                bytes.append(byte)
            }

            return bytes

        default:
            return nil
        }
    }

    // Whether this value is a none of an Optional: `null`, the outermost, or
    // the marker, which holds one. A value held beside a type is one where
    // the value it holds is, so at an Optional it is a some only once the
    // marker holds it.
    var isNone: Bool {
        switch self {
        case .null:
            return true

        case let .struct(instance):
            return instance.isMarker

        case let .existential(existential):
            return existential.value.isNone

        default:
            return false
        }
    }

    // This value as an Optional's some: the marker holding it where it is
    // `null` or a marker, and the value itself otherwise.
    var asSome: Value {
        guard isNone else { return self }

        return .struct(Struct(name: TypeSpelling.marker, [Prelude.markerField: self]))
    }

    // This value read at an Optional, one level: nil for `null`, the none,
    // what the marker holds for a marker, and the value itself otherwise.
    var payload: Value? {
        guard isNone else { return self }

        return self[Prelude.markerField]
    }

    // The type this value is an instance of, under the name a claim writes:
    // a struct under the declared name it carries, and every other kind
    // under the name the language gives it. Bytes are a list in a compact
    // spelling, so they are `Array`. The marker is a some of an Optional, so
    // it is `Optional`.
    public var nominal: Name {
        switch self {
        case .null:
            return TypeSpelling.null

        case .bool:
            return TypeSpelling.bool

        case .int:
            return TypeSpelling.int

        case .double:
            return TypeSpelling.double

        case .string:
            return TypeSpelling.string

        case .bytes, .array:
            return TypeSpelling.array

        case .dictionary:
            return TypeSpelling.dictionary

        case let .struct(instance):
            return instance.isMarker ? TypeSpelling.optional : instance.name

        case .procedure:
            return TypeSpelling.procedure

        case let .existential(existential):
            return existential.value.nominal
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    public static func dictionary(_ entries: [Name: Value]) -> Value {
        .dictionary(Dictionary(entries))
    }

    // What a reading of fields under names makes: a struct of the declared
    // struct the name says. One name holds one field, and a name written
    // twice is refused. The name is a declared struct's: a type's name, or a
    // name the language declares. A marker holding what is not a none is
    // no value, and is refused.
    public static func holding(
        _ fields: some Sequence<(name: Name, value: Value)>,
        named name: Name
    ) throws -> Value {
        let ordered = Array(fields).sorted { one, other in one.name < other.name }

        if let repeated = zip(ordered, ordered.dropFirst()).first(where: { one, other in one.name == other.name }) {
            throw ValueRefused("'\(repeated.0.name)' is written twice")
        }

        guard NameGrammar.structName.holds(name) else {
            throw ValueRefused(NameGrammar.structName.refusal(of: name))
        }

        let held = Struct(layout: Layout(name: name, ordered: ordered.map(\.name)), values: ordered.map(\.value))

        if let refusal = held.markerRefusal {
            throw ValueRefused(refusal)
        }

        return .struct(held)
    }

    // This value with one field written: a field a struct's layout names,
    // where it stands. Any other name is not the declaration's, so a struct
    // refuses it rather than being quietly made something else, and what is
    // no struct holds no fields.
    public func writing(_ name: Name, with value: Value) throws -> Value {
        guard case let .struct(instance) = self else {
            throw ValueRefused("\(nominal) holds no fields, so '\(name)' cannot be written into it")
        }

        return .struct(try instance.writing(name, with: value))
    }

    // Whether a closure this value holds meets the predicate. Stops at the
    // first that does.
    func holdsClosure(where predicate: (Closure) -> Bool) -> Bool {
        !walk { closure in !predicate(closure) }
    }

    // Every closure this value holds, however deep: inside an array, a struct
    // or a dictionary, and inside what a closure captured by copy, which is a
    // value like any other. A cell captured as a hold is a box of the run
    // that made the closure, and what the box holds is that run's.
    func closures(_ body: (Closure) -> Void) {
        walk { closure in
            body(closure)

            return true
        }
    }

    // The same value with every closure in it replaced, innermost first: what
    // a closure holds by value is rewritten and put back into the closure the
    // body is handed. A cell held is the run's box, and stays.
    func rewritten(closures body: (Closure) throws -> Closure) rethrows -> Value {
        switch self {
        case let .procedure(closure):
            let captured = try closure.captured.map { slot, cell -> (slot: Int, cell: Cell) in
                guard case let .value(inner) = cell else { return (slot, cell) }

                return (slot, .value(try inner.rewritten(closures: body)))
            }

            return .procedure(try body(closure.holding(captured)))

        case let .array(items):
            return .array(try items.map { item in try item.rewritten(closures: body) })

        case let .struct(instance):
            return .struct(
                Struct(
                    layout: instance.layout,
                    values: try instance.values.map { value in try value.rewritten(closures: body) }
                )
            )

        case let .dictionary(dictionary):
            return .dictionary(
                Value.Dictionary(
                    ordered: try dictionary.entries.map { entry in
                        (entry.key, try entry.value.rewritten(closures: body))
                    }
                )
            )

        case let .existential(existential):
            return .existential(existential.holding(try existential.value.rewritten(closures: body)))

        case .null, .bool, .int, .double, .string, .bytes:
            return self
        }
    }

    // The same value with the type every existential in it and in its parts
    // holds spelled, read in the table it was numbered in: what a build hands
    // a link. A closure's cells are its own, and stay.
    func spelled(in table: LoweredTypeTable) -> Value {
        rewritten { existential in existential.spelled(in: table) }
    }

    // The same value with every type it and its parts hold spelled read in a
    // link's table. A closure's cells are its own, and stay.
    func standing(in table: LoweredTypeTable) -> Value {
        rewritten { existential in existential.standing(in: table) }
    }

    // Whether this is a value held beside the type it was read as.
    var isExistential: Bool {
        if case .existential = self { true } else { false }
    }

    // The value an existential holds, and any other value as it is: what
    // takes a value read as a contract where its type is read already.
    var opened: Value {
        guard case let .existential(existential) = self else { return self }

        return existential.value
    }

    // The same value with every existential in it and in its parts replaced
    // by the value it holds: what meets `Any` or leaves through a door, where
    // nothing reads a part as a contract. A closure's cells are its own, and
    // stay. A value holding none is handed back as it is, uncopied.
    var dropped: Value {
        holdsExistential ? stripped : self
    }

    // A field of a struct, and nil for anything else. Several return values
    // travel as one struct because a procedure returns one value, so reading
    // a field back out is the ordinary thing a host does with what a run gave
    // it.
    public subscript(field: Name) -> Value? {
        guard case let .struct(instance) = self else { return nil }

        return instance[field]
    }

    // The elements at these positions, in the spelling this value is. Nil for
    // what has no elements to take, the way `elements` returns nil.
    //
    // This is for the procedures that only put a collection's own elements in
    // another order or take fewer of them, and so never have to look at one:
    // bytes are rearranged as the bytes they are, never read out as values
    // and written back.
    //
    // For a position this value does not have, the return value is the one a
    // value with no elements at all gets: nil. A caller's own arithmetic
    // decides the positions, so one out of range is refused here and not
    // trapped on.
    public func elements(at positions: some Sequence<Int>) -> Value? {
        switch self {
        case let .bytes(bytes):
            guard let taken = Self.taken(bytes, at: positions) else { return nil }

            return .bytes(taken)

        case let .array(array):
            guard let taken = Self.taken(array, at: positions) else { return nil }

            return .array(taken)

        default:
            return nil
        }
    }

    // This value with one more element at one end, in the spelling it is. Nil
    // for what has no elements, the way the two above return nil.
    //
    // Only the arriving element is looked at, because it is the only one that
    // can make a compact spelling stop holding: the ones already there are
    // bytes by construction.
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

    // These elements, spelled the way this value is. The other half of
    // `elements`, which reads a compact spelling as the array it is: this
    // writes an array back into the compact spelling where it still holds,
    // so a procedure that returns a collection's own elements, rearranged or
    // fewer, returns bytes when it was given bytes.
    //
    // Where it no longer holds, a byte's slot now carrying something that is
    // not one, the return value is a plain array, because the spelling is a fact
    // about the value and saying otherwise would be a claim no value backs.
    //
    // A procedure that builds new elements does not come through here: what it
    // returns is its own value however it was reached.
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

    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case let (.existential(left), _):
            return left.value == rhs

        case let (_, .existential(right)):
            return lhs == right.value

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

        // Bytes are not a string: no encoding is assumed, so equality is the
        // bytes themselves and no Unicode rule applies.
        case let (.bytes(left), .bytes(right)):
            return left == right

        // Element by element: an array's own `==` returns true for a shared
        // buffer without asking its elements, and a procedure is equal to
        // nothing.
        case let (.array(left), .array(right)):
            return left.count == right.count && zip(left, right).allSatisfy { mine, theirs in mine == theirs }

        case let (.struct(left), .struct(right)):
            return left == right

        case let (.dictionary(left), .dictionary(right)):
            return left == right

        default:
            return false
        }
    }

    // Sameness as `equal` returns it. Strict except that worth unifies an
    // `Int` with the `Double` of the same worth, and bytes, being an
    // array, equal the array of the same elements, applied recursively
    // through arrays, structs and dictionaries.
    public func matches(_ other: Value) -> Bool {
        switch (self, other) {
        case let (.existential(mine), _):
            return mine.value.matches(other)

        case let (_, .existential(theirs)):
            return matches(theirs.value)

        case let (.int(integer), .double(double)), let (.double(double), .int(integer)):
            return Value.sameWorth(integer: integer, double: double)

        // Bytes are an array of integers in a compact spelling, so the
        // elements are compared, read through `elements`, which owns the
        // equation.
        case (.bytes, .array), (.array, .bytes):
            guard let mine = elements, let theirs = other.elements else { return false }

            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.array(left), .array(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0.matches(pair.1) }

        // Both hold their fields in name order, so two structs match field by
        // field.
        case let (.struct(left), .struct(right)):
            return left.layout == right.layout
                && zip(left.values, right.values).allSatisfy { mine, theirs in mine.matches(theirs) }

        case let (.dictionary(left), .dictionary(right)):
            return left.count == right.count
                && zip(left.entries, right.entries).allSatisfy { mine, theirs in
                    mine.key.matches(theirs.key) && mine.value.matches(theirs.value)
                }

        default:
            return self == other
        }
    }

    // This value with one part replaced: the part the path names, in a struct
    // by the place the build put the field at, in a dictionary by key and in a list
    // by position, a list returned in the spelling it was in where that
    // still holds. The rest is kept as it was. The build judged the
    // path against the value's declared type, and every index was read to a
    // value before this. A dictionary's keys are its own, so an entry under one not
    // held yet is made where the write lands on it, and holds nothing for a
    // write to pass through.
    func writing(_ value: Value, at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return value }

        // A step reaches into the value a contract's holds, and what it holds
        // stays beside it.
        if case let .existential(existential) = self {
            return .existential(
                existential.holding(try existential.value.writing(value, at: path, under: rendered))
            )
        }

        let rest = Array(path.dropFirst())

        if case let .index(.int(index)) = step, let elements {
            guard index >= 0, index < elements.count else {
                throw ExecutionError("'\(rendered)' writes element \(index) of an array holding \(elements.count)")
            }

            var written = Array(elements)
            written[index] = try written[index].writing(value, at: rest, under: rendered)

            return respelled(written)
        }

        switch (self, step) {
        case let (.struct(instance), .field(position, name)):
            guard instance.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' writes '\(name)' past the fields this struct holds")
            }

            let written = try instance.values[position].writing(value, at: rest, under: rendered)

            return .struct(instance.writing(at: position, with: written))

        // A field by its name, where the build laid out no struct.
        case let (.struct(instance), .name(name)):
            guard let field = instance[name] else {
                throw ExecutionError("'\(rendered)' writes '\(name)' past the fields this struct holds")
            }

            return .struct(try instance.writing(name, with: try field.writing(value, at: rest, under: rendered)))

        case let (.dictionary(dictionary), .index(key)):
            guard let held = dictionary[key: key] else {
                guard rest.isEmpty else {
                    throw ExecutionError(
                        "'\(rendered)' writes through \(Path([step.spelled]).rendered),"
                            + " an entry the dictionary does not hold. Write the whole entry first"
                    )
                }

                return .dictionary(dictionary.writing(key: key, with: value))
            }

            return .dictionary(dictionary.writing(key: key, with: try held.writing(value, at: rest, under: rendered)))

        default:
            throw ExecutionError(
                "'\(rendered)' writes \(Path([step.spelled]).rendered) into \(nominal), which has no such part"
            )
        }
    }

    // MARK: - Private
    private var holdsExistential: Bool {
        switch self {
        case .existential:
            return true

        case let .array(items):
            return items.contains { item in item.holdsExistential }

        case let .struct(instance):
            return instance.values.contains { value in value.holdsExistential }

        case let .dictionary(dictionary):
            return dictionary.entries.contains { entry in entry.key.holdsExistential || entry.value.holdsExistential }

        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return false
        }
    }

    // The same value with every existential in it replaced, innermost first:
    // what an existential holds is rewritten and put back into what the body
    // returns. A dictionary's keys are walked as its values are.
    private func rewritten(existentials body: (Existential) -> Existential) -> Value {
        guard holdsExistential else { return self }

        switch self {
        case let .existential(existential):
            return .existential(body(existential.holding(existential.value.rewritten(existentials: body))))

        case let .array(items):
            return .array(items.map { item in item.rewritten(existentials: body) })

        case let .struct(instance):
            return .struct(
                Struct(layout: instance.layout, values: instance.values.map { value in value.rewritten(existentials: body) })
            )

        case let .dictionary(dictionary):
            return .dictionary(
                Value.Dictionary(
                    ordered: dictionary.entries.map { entry in
                        (entry.key.rewritten(existentials: body), entry.value.rewritten(existentials: body))
                    }
                )
            )

        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return self
        }
    }

    private var stripped: Value {
        switch self {
        case let .existential(existential):
            return existential.value.stripped

        case let .array(items):
            return .array(items.map(\.stripped))

        case let .struct(instance):
            return .struct(Struct(layout: instance.layout, values: instance.values.map(\.stripped)))

        case let .dictionary(dictionary):
            return .dictionary(
                Value.Dictionary(ordered: dictionary.entries.map { entry in (entry.key.stripped, entry.value.stripped) })
            )

        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return self
        }
    }

    // The walk itself. The body returns whether to go on, and the walk
    // returns whether it reached the end.
    @discardableResult
    private func walk(_ body: (Closure) -> Bool) -> Bool {
        switch self {
        case let .procedure(closure):
            guard body(closure) else { return false }

            for (_, cell) in closure.captured {
                guard case let .value(captured) = cell else { continue }
                guard captured.walk(body) else { return false }
            }

            return true

        case let .array(items):
            return items.allSatisfy { item in item.walk(body) }

        case let .struct(instance):
            return instance.values.allSatisfy { value in value.walk(body) }

        case let .dictionary(dictionary):
            return dictionary.entries.allSatisfy { entry in entry.key.walk(body) && entry.value.walk(body) }

        case let .existential(existential):
            return existential.value.walk(body)

        case .null, .bool, .int, .double, .string, .bytes:
            return true
        }
    }

    // Whether a `Double` is exactly an `Int`'s worth, judged without
    // converting the `Int`, which would round past 2^53. 0x1p63 is
    // the edge of what an `Int` can be, written exactly where
    // `Double(Int.max)` would round past it; a `Double` that is not a number
    // or is infinite is the worth of none.
    private static func sameWorth(integer: Int, double: Double) -> Bool {
        guard double >= -0x1p63, double < 0x1p63, double.rounded(.down) == double else { return false }

        return Int(double) == integer
    }

    // These positions taken in order, and nil where one of them is not a
    // position the elements hold, so a caller that counted wrong gets nil
    // rather than a trap. Written once for both spellings' storage.
    private static func taken<Element>(_ elements: [Element], at positions: some Sequence<Int>) -> [Element]? {
        var taken = [Element]()

        for position in positions {
            guard elements.indices.contains(position) else { return nil }

            taken.append(elements[position])
        }

        return taken
    }
}
