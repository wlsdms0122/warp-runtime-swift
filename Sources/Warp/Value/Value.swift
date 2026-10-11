//
//  Value.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a program computes over: data, and one kind that is not data. A
// procedure is a value here, so a body can be passed, kept and answered with.
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

    // Fields under names, and the name of the declared record it is a value
    // of. Two records of one structure under two names are two values.
    case record(Record)

    // Entries under keys that are values: what a document's mappings are,
    // what a host builds out of raw data, and what a map literal makes. A map
    // is never a record.
    case dictionary(Dictionary)

    case procedure(Closure)

    // Entries under keys that are values. They stand in the key order, the
    // order the canonical writing and `keys` walk a map in, and a key is found
    // by that order and then by sameness, so two keys that are the same value
    // are one key: `1` and `1.0`, two spellings of one text, bytes and the
    // array of their numbers. A key that is the same as no value, a fraction
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

        // A map keyed by text, the way a document's mappings are keyed by
        // the names it writes.
        public init(_ fields: [Name: Value]) {
            self.entries = fields
                .map { field in (key: Value.string(field.key.spelling), value: field.value) }
                .sorted { one, other in Self.order(one.key, other.key) == .orderedAscending }
        }

        // The inner door: entries in the key order, under keys none of which
        // is the same as another. An object's list of entries carries both
        // facts once its reading judged the order, so what stands on it comes
        // through here rather than being sorted again. A value born outside a
        // link has neither behind it and comes through the door above.
        init(ordered entries: [(key: Value, value: Value)]) {
            self.entries = entries
        }

        // MARK: - Public
        public subscript(key key: Value) -> Value? {
            let (position, found) = place(of: key)

            return found ? entries[position].value : nil
        }

        // The entry under a text key, the way a document's mapping is read
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

        // This map with one entry written: the value replaced where the key is
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

        // The same under a text key.
        public func writing(_ name: Name, with value: Value) -> Dictionary {
            writing(key: .string(name.spelling), with: value)
        }

        // This map without the entry under this key, or as it is where none
        // is held.
        public func removing(key: Value) -> Dictionary {
            let (position, found) = place(of: key)

            guard found else { return self }

            var written = entries
            written.remove(at: position)

            return Dictionary(ordered: written)
        }

        // The same under a text key.
        public func removing(_ name: Name) -> Dictionary {
            removing(key: .string(name.spelling))
        }

        // This map with every value put through `transform`, under the same
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
        // number, text, list, map, record, and a procedure last), then false
        // before true, numbers by worth, text as `String` orders it, which is
        // its scalars in normal form C, lists element by element with a
        // shorter one first on a common start, maps entry by entry, and
        // records by name and then field by field. Bytes are the list of
        // their numbers. Two keys the same value stand at one place; a
        // fraction that is not a number stands after every number, and a
        // procedure after everything, each at one place it shares with its
        // own kind and is the same as nothing there.
        static func order(_ left: Value, _ right: Value) -> ComparisonResult {
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

            case let (.record(mine), .record(theirs)):
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
            case .record: 6
            case .procedure: 7
            }
        }

        // Two numbers by what they are worth, exactly: a whole number and a
        // fraction are compared without converting the whole number, which
        // would round past 2^53. A fraction that is not a number stands after
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

            case let (.int(whole), .double(fraction)):
                return worth(whole: whole, fraction: fraction)

            case let (.double(fraction), .int(whole)):
                switch worth(whole: whole, fraction: fraction) {
                case .orderedAscending: return .orderedDescending
                case .orderedDescending: return .orderedAscending
                case .orderedSame: return .orderedSame
                }

            default:
                return .orderedSame
            }
        }

        // A whole number against a fraction: ascending where the whole number
        // is worth less.
        private static func worth(whole: Int, fraction: Double) -> ComparisonResult {
            guard !fraction.isNaN else { return .orderedAscending }
            guard fraction >= -0x1p63 else { return .orderedDescending }
            guard fraction < 0x1p63 else { return .orderedAscending }

            let floor = fraction.rounded(.down)
            let truncated = Int(floor)

            if whole < truncated { return .orderedAscending }
            if whole > truncated { return .orderedDescending }

            return floor == fraction ? .orderedSame : .orderedAscending
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
    // What is said wherever a value stands where a document can reach it.
    static let procedureIsNotData = "a procedure is not data, so it cannot stand"
        + " where a document reaches; a body a program carries is written as a closure"

    // Whether a procedure is anywhere in here, however deep.
    //
    // The types nest, so the question does: a procedure one array inside a
    // record is still a procedure this value holds, and a check that looked
    // only at the outside would pass a program that carries one and refuse the
    // same program written without the wrapper.
    public var holdsProcedure: Bool {
        holdsClosure { _ in true }
    }

    // Whether a record is anywhere in here, however deep. A record is the
    // value of a declared record, made where a literal is written into one or
    // handed through a door under the record's name.
    var holdsRecord: Bool {
        switch self {
        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return false

        case let .array(elements):
            return elements.contains { element in element.holdsRecord }

        case let .dictionary(held):
            return held.entries.contains { key, value in key.holdsRecord || value.holdsRecord }

        case .record:
            return true
        }
    }

    // The elements a value is indexed by, and nil for what has none. This is
    // where the `bytes = Array<Int>` equation lives on the value side: an
    // array answers its own elements and bytes answer theirs as the ints they
    // are, lazily, so a compact spelling is not unpacked to read one element,
    // and a procedure taking either through `Any` reads this one projection
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
    // an array of whole numbers inside a byte's range read out one by one.
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

    // The type this value is an instance of, under the name a claim writes:
    // a record under the declared name it carries, and every other kind
    // under the name the language gives it. Bytes are a list in a compact
    // spelling, so they are `Array`.
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

        case let .record(record):
            return record.name

        case .procedure:
            return TypeSpelling.procedure
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    public static func dictionary(_ entries: [Name: Value]) -> Value {
        .dictionary(Dictionary(entries))
    }

    // What a reading of fields under names makes: a record of the declared
    // record a name says, and a map keyed by the names' text where it says
    // none. Either way one name holds one field, and a name written twice is
    // refused. The name is a declared type's, so it holds a type's grammar.
    public static func holding(
        _ fields: some Sequence<(name: Name, value: Value)>,
        named name: Name?
    ) throws -> Value {
        let ordered = Array(fields).sorted { one, other in one.name < other.name }

        if let repeated = zip(ordered, ordered.dropFirst()).first(where: { one, other in one.name == other.name }) {
            throw ValueRefused("'\(repeated.0.name)' is written twice")
        }

        guard let name else {
            return .dictionary(
                Value.Dictionary(ordered: ordered.map { field in (key: .string(field.name.spelling), value: field.value) })
            )
        }

        guard NameGrammar.type.holds(name) else {
            throw ValueRefused(NameGrammar.type.refusal(of: name))
        }

        return .record(Record(layout: Layout(name: name, ordered: ordered.map(\.name)), values: ordered.map(\.value)))
    }

    // This value with one field written: a field a record's layout names,
    // where it stands, or a map's entry under the name's text. Any other
    // name is not the declaration's, so a record refuses it rather than
    // being quietly made something else.
    public func writing(_ name: Name, with value: Value) throws -> Value {
        switch self {
        case let .record(record):
            return .record(try record.writing(name, with: value))

        case let .dictionary(held):
            return .dictionary(held.writing(name, with: value))

        default:
            throw ValueRefused("\(nominal) holds no fields, so '\(name)' cannot be written into it")
        }
    }

    // Whether a closure this value holds answers the predicate. Stops at the
    // first that does.
    func holdsClosure(where predicate: (Closure) -> Bool) -> Bool {
        !walk { closure in !predicate(closure) }
    }

    // Every closure this value holds, however deep: inside an array, a record
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
    // a closure holds by value is rewritten and put back into what the body
    // answers, so the body answers for the closure alone. A cell held is the
    // run's box, and stays.
    func rewritten(closures body: (Closure) throws -> Closure) rethrows -> Value {
        switch self {
        case let .procedure(closure):
            let captured = try closure.captured.map { slot, cell -> (slot: Int, cell: Cell) in
                guard case let .value(inner) = cell else { return (slot, cell) }

                return (slot, .value(try inner.rewritten(closures: body)))
            }

            return .procedure(try body(closure).holding(captured))

        case let .array(items):
            return .array(try items.map { item in try item.rewritten(closures: body) })

        case let .record(record):
            return .record(
                Record(
                    layout: record.layout,
                    values: try record.values.map { value in try value.rewritten(closures: body) }
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

        case .null, .bool, .int, .double, .string, .bytes:
            return self
        }
    }

    // A field of a record, and nil for anything else. Several answers travel as
    // one record because a procedure answers one value, so reading a field back
    // out is the ordinary thing a host does with what a run gave it.
    public subscript(field: Name) -> Value? {
        switch self {
        case let .record(record): record[field]
        case let .dictionary(dictionary): dictionary[field]
        default: nil
        }
    }

    // The elements at these positions, in the spelling this value is. Nil for
    // what has no elements to take, the way `elements` answers nil.
    //
    // This is for the procedures that only put a collection's own elements in
    // another order or take fewer of them, and so never have to look at one.
    // Saying which by position lets bytes be rearranged as the bytes they are:
    // reading them out as values and writing them back would cost the boxing
    // twice over, which is the cost being compact exists to avoid.
    //
    // A position this value does not have is answered the way a value with no
    // elements at all is: with nil. A caller's own arithmetic decides the
    // positions, so one out of range is refused here and not trapped on.
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
    // for what has no elements, the way the two above answer nil.
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

    // These elements, spelled the way this value is. The other half of the
    // projection above: `elements` reads a compact spelling as the array it is,
    // and this writes an array back into the compact spelling where it still
    // holds, so a procedure that answers a collection's own elements, rearranged or
    // fewer, answers bytes when it was given bytes.
    //
    // Where it no longer holds, a byte's slot now carrying something that is
    // not one, the answer is a plain array, because the spelling is a fact
    // about the value and saying otherwise would be a claim no value backs.
    //
    // A procedure that builds new elements does not come through here: what it
    // answers is its own value however it was reached.
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

        // Element by element: an array's own `==` answers a shared buffer
        // without asking its elements, and a procedure is equal to nothing.
        case let (.array(left), .array(right)):
            return left.count == right.count && zip(left, right).allSatisfy { mine, theirs in mine == theirs }

        case let (.record(left), .record(right)):
            return left == right

        case let (.dictionary(left), .dictionary(right)):
            return left == right

        default:
            return false
        }
    }

    // How two values of one kind stand to each other, for the kinds that
    // order: whole numbers, fractions and strings. Nil is a pair with no
    // order: two of different kinds, a kind that does not order, and a
    // fraction that is not a number, which orders with nothing. `lessThan`
    // answers the language's own types by this.
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

        case let (.string(first), .string(second)):
            return first == second
                ? .orderedSame
                : first < second ? .orderedAscending : .orderedDescending

        default:
            return nil
        }
    }

    // Sameness as `equal` answers it. Strict except that worth unifies a
    // whole number with the fraction of the same worth, and bytes, being an
    // array, equal the array of the same elements, applied recursively
    // through arrays, records and maps.
    public func matches(_ other: Value) -> Bool {
        switch (self, other) {
        case let (.int(whole), .double(fraction)), let (.double(fraction), .int(whole)):
            return Value.sameWorth(whole: whole, fraction: fraction)

        // Bytes are an array of whole numbers in a compact spelling, so the
        // elements are compared, read through the one projection that owns
        // the equation.
        case (.bytes, .array), (.array, .bytes):
            guard let mine = elements, let theirs = other.elements else { return false }

            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.array(left), .array(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0.matches(pair.1) }

        // Both hold their fields in name order, so two records match field by
        // field.
        case let (.record(left), .record(right)):
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

    // The part a path names, in a record by the place the build put the field
    // at, in a map by key and in an array by position. Every index was read
    // to a value before this, and the build judged the path against the
    // value's declared type, so a part not held is refused as what it is: an
    // entry not written yet, or a type with no such part.
    func reading(at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return self }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try record.values[position].reading(at: rest, under: rendered)

        case let (.record(record), .name(name)):
            guard let field = record[name] else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try field.reading(at: rest, under: rendered)

        case let (.dictionary(map), .index(key)):
            guard let entry = map[key: key] else {
                throw ExecutionError(
                    "'\(rendered)' reads \(Path([step.spelled]).rendered), which is not written yet"
                )
            }

            return try entry.reading(at: rest, under: rendered)

        case let (.array(elements), .index(.int(index))):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' reads element \(index) of an array holding \(elements.count)"
                )
            }

            return try elements[index].reading(at: rest, under: rendered)

        default:
            throw ExecutionError(
                "'\(rendered)' reads \(Path([step.spelled]).rendered) of \(nominal), which has no such part"
            )
        }
    }

    // The same, with nil where the path reaches an entry not written yet or
    // an element past the end of a list, places nothing holds now rather
    // than mistakes.
    func written(at path: [Projection], under rendered: String) throws -> Value? {
        guard let step = path.first else { return self }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try record.values[position].written(at: rest, under: rendered)

        case let (.record(record), .name(name)):
            guard let field = record[name] else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try field.written(at: rest, under: rendered)

        case let (.dictionary(map), .index(key)):
            return try map[key: key]?.written(at: rest, under: rendered)

        case let (.array(elements), .index(.int(index))):
            guard elements.indices.contains(index) else { return nil }

            return try elements[index].written(at: rest, under: rendered)

        default:
            throw ExecutionError(
                "'\(rendered)' reads \(Path([step.spelled]).rendered) of \(nominal), which has no such part"
            )
        }
    }

    // This value with one part replaced: the part the path names, in a record
    // by the place the build put the field at, in a map by key and in an
    // array by position. The rest is kept as it was. The build judged the
    // path against the value's declared type, and every index was read to a
    // value before this. A map's keys are its own, so an entry under one not
    // held yet is made.
    func writing(_ value: Value, at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' writes '\(name)' past the fields this record holds")
            }

            let written = try record.values[position].writing(value, at: rest, under: rendered)

            return .record(record.writing(at: position, with: written))

        // A field by its name, of a record a call decides.
        case let (.record(record), .name(name)):
            guard let field = record[name] else {
                throw ExecutionError("'\(rendered)' writes '\(name)' past the fields this record holds")
            }

            return .record(try record.writing(name, with: try field.writing(value, at: rest, under: rendered)))

        case let (.dictionary(map), .index(key)):
            let entry = try (map[key: key] ?? .null).writing(value, at: rest, under: rendered)

            return .dictionary(map.writing(key: key, with: entry))

        case let (.array(elements), .index(.int(index))):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' writes element \(index) of an array holding \(elements.count)"
                )
            }

            var written = elements
            written[index] = try elements[index].writing(value, at: rest, under: rendered)
            return .array(written)

        case (.null, _):
            throw ExecutionError(
                "'\(rendered)' writes through \(Path([step.spelled]).rendered), which holds nothing yet."
                    + " Write the whole entry first"
            )

        default:
            throw ExecutionError(
                "'\(rendered)' writes \(Path([step.spelled]).rendered) into \(nominal), which has no such part"
            )
        }
    }

    // MARK: - Private
    // The walk itself. The body answers whether to go on, and the walk
    // answers whether it reached the end.
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

        case let .record(record):
            return record.values.allSatisfy { value in value.walk(body) }

        case let .dictionary(dictionary):
            return dictionary.entries.allSatisfy { entry in entry.key.walk(body) && entry.value.walk(body) }

        case .null, .bool, .int, .double, .string, .bytes:
            return true
        }
    }

    // Whether a fraction is exactly a whole number's worth, judged without
    // converting the whole number, which would round past 2^53. 0x1p63 is
    // the edge of what a whole number can be, written exactly where
    // `Double(Int.max)` would round past it; a fraction that is not a number
    // or is infinite is the worth of none.
    private static func sameWorth(whole integer: Int, fraction: Double) -> Bool {
        guard fraction >= -0x1p63, fraction < 0x1p63, fraction.rounded(.down) == fraction else { return false }

        return Int(fraction) == integer
    }

    // These positions taken in order, and nil where one of them is not a
    // position the elements hold, so a caller that counted wrong is answered
    // rather than trapped. Written once for both spellings' storage.
    private static func taken<Element>(_ elements: [Element], at positions: some Sequence<Int>) -> [Element]? {
        var taken = [Element]()

        for position in positions {
            guard elements.indices.contains(position) else { return nil }

            taken.append(elements[position])
        }

        return taken
    }
}
