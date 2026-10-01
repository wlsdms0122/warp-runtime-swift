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

    // Fields under names, and the name of the declared type the record
    // settled to, where it has. A record made by a literal, answered by a
    // native procedure or read out of a document has no name; it takes one the
    // first time it settles into a slot that declares a type, and from then
    // on it fits only that name. Two records of one structure under two names
    // are two values.
    case record(Record)

    // Names and values where the names are data: what a document hands in,
    // what a host builds out of raw data, and what a procedure that reads names
    // answers. A declaration is what turns one of these into a record.
    case dictionary(Dictionary)

    case procedure(Closure)

    // The entries stand in ascending byte order of their names, the order the
    // canonical writing uses, and a name is found by comparing bytes.
    public struct Dictionary: Sendable, Equatable {
        // MARK: - Property
        // In ascending byte order of `name`, as `Name`'s `<` orders them.
        public let entries: [(name: Name, value: Value)]

        public var names: [Name] {
            entries.map(\.name)
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
        // Entries in any order under names none of which repeats.
        public init(_ entries: [(name: Name, value: Value)]) throws {
            let sorted = entries.sorted { one, other in one.name < other.name }

            if let repeated = zip(sorted, sorted.dropFirst()).first(where: { one, other in one.name == other.name }) {
                throw ValueRefused("'\(repeated.0.name)' is written twice")
            }

            self.entries = sorted
        }

        public init(_ fields: [Name: Value]) {
            self.entries = fields.map { field in (name: field.key, value: field.value) }
                .sorted { one, other in one.name < other.name }
        }

        // The inner door: entries in the order a name puts them, under names
        // none of which repeats. A layout carries both facts, and so does an
        // object's list of entries once its reading judged the order, so what
        // stands on either comes through here rather than being sorted again.
        // A value born outside a link has neither behind it and comes through
        // the door above.
        init(ordered entries: [(name: Name, value: Value)]) {
            self.entries = entries
        }

        private init(keeping entries: [(name: Name, value: Value)]) {
            self.entries = entries
        }

        // MARK: - Public
        public subscript(name: Name) -> Value? {
            let (position, found) = place(of: name)

            return found ? entries[position].value : nil
        }

        // This dictionary with one entry written: the value replaced where the
        // name is held, and the entry put where it sorts where it is not.
        public func writing(_ name: Name, with value: Value) -> Dictionary {
            var written = entries
            let (position, found) = place(of: name)

            if found {
                written[position].value = value
            } else {
                written.insert((name: name, value: value), at: position)
            }

            return Dictionary(keeping: written)
        }

        // This dictionary without the entry of this name, or as it is where none
        // is held.
        public func removing(_ name: Name) -> Dictionary {
            let (position, found) = place(of: name)

            guard found else { return self }

            var written = entries
            written.remove(at: position)

            return Dictionary(keeping: written)
        }

        // This dictionary with every value put through `transform`, under the
        // same names in the same order.
        public func mapValues(_ transform: (Name, Value) throws -> Value) rethrows -> Dictionary {
            Dictionary(
                keeping: try entries.map { entry in (name: entry.name, value: try transform(entry.name, entry.value)) }
            )
        }

        public static func == (lhs: Dictionary, rhs: Dictionary) -> Bool {
            lhs.entries.count == rhs.entries.count
                && zip(lhs.entries, rhs.entries).allSatisfy { mine, theirs in
                    mine.name == theirs.name && mine.value == theirs.value
                }
        }

        // MARK: - Private
        // Where a name is, or where it would go: the first position whose name
        // does not precede it, and whether the name there is it.
        private func place(of name: Name) -> (Int, Bool) {
            var low = 0
            var high = entries.count

            while low < high {
                let middle = (low + high) / 2

                if entries[middle].name < name {
                    low = middle + 1
                } else {
                    high = middle
                }
            }

            return (low, low < entries.count && entries[low].name == name)
        }
    }

    // MARK: - Property
    // What is said wherever a value stands where a document can reach it.
    public static let procedureIsNotData = "a procedure is not data, so it cannot stand"
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

        case .record, .dictionary:
            return .record

        case .procedure:
            return .procedure
        }
    }

    // The elements a value is indexed by, and nil for what has none. This is
    // where the `bytes = array<byte>` equation lives on the value side: an
    // array answers its own elements and bytes answer theirs as the ints they
    // are, lazily, so a compact spelling is not unpacked to read one element,
    // and a procedure taking either through `any` reads this one projection
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

    // The name this value wears, where it wears one. A record settled under a
    // declared type carries its label; nothing else names itself.
    public var nominal: Name? {
        guard case let .record(record) = self else { return nil }

        return record.name
    }

    // Whether this holds fields under names: a record's layout's, or a
    // dictionary's own.
    public var holdsFields: Bool {
        switch self {
        case .record, .dictionary: true
        default: false
        }
    }

    // This value's fields as names beside values, and nil for what holds
    // none. A record's names come from its layout.
    public var asDictionary: Value.Dictionary? {
        switch self {
        case let .dictionary(dictionary):
            return dictionary

        case let .record(record):
            return record.asDictionary

        default:
            return nil
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    public static func dictionary(_ entries: [Name: Value]) -> Value {
        .dictionary(Dictionary(entries))
    }

    // What a reading of fields under names makes. A name is a layout's, so a
    // reading that carries one makes a record; without one the names stay the
    // value's own data. Either way one name holds one field, and a name
    // written twice is refused.
    public static func holding(
        _ fields: some Sequence<(name: Name, value: Value)>,
        named name: Name?
    ) throws -> Value {
        // The dictionary proved the order and that no name repeats, so the
        // layout is built rather than checked again.
        let held = try Value.Dictionary(Array(fields))

        guard let name else { return .dictionary(held) }

        return .record(Record(layout: Layout(name: name, ordered: held.names), values: held.values))
    }

    // This value with one field written. A field a record's layout names is
    // written where it stands. Any other name is not the declaration's, so a
    // value that settled to one is refused rather than quietly made something
    // else, and a value that settled to none holds the new name as data, the
    // way the dictionary it equals does.
    public func writing(_ name: Name, with value: Value) throws -> Value {
        switch self {
        case let .record(record) where record.layout.position(of: name) != nil:
            return .record(try record.writing(name, with: value))

        case let .record(record):
            if let settled = record.name {
                throw ValueRefused("\(settled) declares no field '\(name)'")
            }

            return .dictionary(record.asDictionary.writing(name, with: value))

        case let .dictionary(held):
            return .dictionary(held.writing(name, with: value))

        default:
            throw ValueRefused("\(type) holds no fields, so '\(name)' cannot be written into it")
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
                        (entry.name, try entry.value.rewritten(closures: body))
                    }
                )
            )

        case .null, .bool, .int, .double, .string, .bytes:
            return self
        }
    }

    // A field of a record, and nil for anything else. Several answers travel as
    // one record because a procedure answers one value, so reading a field back
    // out is the ordinary thing a caller does with what a run gave it.
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

        case let (.record(record), .dictionary(dictionary)),
            let (.dictionary(dictionary), .record(record)):
            return same(record, dictionary) { mine, theirs in mine == theirs }

        default:
            return false
        }
    }

    // How two values stand to each other, for the kinds that order: numbers
    // among themselves and strings among themselves. Nil is a pair with no
    // order: mixed kinds, the kinds that do not order, and a fraction that is
    // not a number, which orders with nothing. Every consumer of order
    // (equality across numeric width, `lessThan`/`greaterThan`, `sorted`,
    // `min`/`max`) reads this one answer, so a whole beside a fraction is
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

    // The equality conditions test with. Strict except that worth unifies
    // across spellings: int and double across numeric width, and bytes beside
    // an array of what its elements are worth, applied recursively through
    // arrays and records.
    public func matches(_ other: Value) -> Bool {
        switch (self, other) {
        case (.int, .double), (.double, .int):
            return Value.order(self, other) == .orderedSame

        // Bytes are an array of bytes in a compact spelling. `1` and `1.0`
        // again, one collection up: the worth is the elements', read through
        // the one projection that owns the equation.
        case (.bytes, .array), (.array, .bytes):
            guard let mine = elements, let theirs = other.elements else { return false }

            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.array(left), .array(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0.matches(pair.1) }

        // Both hold their entries in name order, so two records match
        // entry by entry.
        case let (.record(left), .record(right)):
            return left.layout == right.layout
                && zip(left.values, right.values).allSatisfy { mine, theirs in mine.matches(theirs) }

        case let (.dictionary(left), .dictionary(right)):
            return left.count == right.count
                && zip(left.entries, right.entries).allSatisfy { mine, theirs in
                    mine.name == theirs.name && mine.value.matches(theirs.value)
                }

        case let (.record(record), .dictionary(dictionary)),
            let (.dictionary(dictionary), .record(record)):
            return Value.same(record, dictionary) { mine, theirs in mine.matches(theirs) }

        default:
            return self == other
        }
    }

    // The part a path names, in a record by the place the build put the field
    // at, in a dictionary by key and in an array by position. Every index was
    // read to a position before this, and the build judged the path against
    // the value's declared type, so a part not held is refused as what it
    // is: an entry not written yet, or a type with no such part.
    func reading(at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return self }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try record.values[position].reading(at: rest, under: rendered)

        case let (_, .key(name)) where holdsFields:
            guard let field = self[name] else {
                throw ExecutionError("'\(rendered)' reads '\(name)', which is not written yet")
            }

            return try field.reading(at: rest, under: rendered)

        case let (.array(elements), .index(index)):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' reads element \(index) of an array holding \(elements.count)"
                )
            }

            return try elements[index].reading(at: rest, under: rendered)

        default:
            throw ExecutionError(
                "'\(rendered)' reads \(Path([step.spelled]).rendered) of \(type), which has no such part"
            )
        }
    }

    // This value with one part replaced: the part the path names, in a record
    // by the place the build put the field at, in a dictionary by name and in
    // an array by position. The rest is kept as it was. The build judged the
    // path against the value's declared type, and every index was read to a
    // position before this. A dictionary's names are its own, so one not
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

        // A name written into what holds its names as data. The build judged
        // the path, so a name that reaches here is one it allowed.
        case let (_, .key(name)) where holdsFields:
            do {
                return try writing(name, with: try (self[name] ?? .null).writing(value, at: rest, under: rendered))
            } catch let refused as ValueRefused {
                throw ExecutionError("'\(rendered)' writes '\(name)', and \(refused.message)")
            }

        case let (.array(elements), .index(index)):
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
                "'\(rendered)' writes \(Path([step.spelled]).rendered) into \(type), which has no such part"
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
            return dictionary.entries.allSatisfy { entry in entry.value.walk(body) }

        case .null, .bool, .int, .double, .string, .bytes:
            return true
        }
    }

    // How a whole number stands against a fraction, exactly at every size.
    // Converting the whole to binary64 rounds above 2^53, and worth must not
    // depend on the rounding, so the fraction is taken apart instead: its whole
    // part meets the int exactly, and only a tie reads what is left.
    private static func order(whole integer: Int, fraction: Double) -> ComparisonResult? {
        guard !fraction.isNaN else { return nil }

        // Past either end of what an int can be (0x1p63 is the int's own edge,
        // written exactly where `Double(Int.max)` would round past it) the
        // answer needs no digits, and infinity, which only a host can hand in,
        // is answered by the same two lines.
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

    // Whether a record and a dictionary hold the same fields. A record that
    // settled to a name is that name's, and no dictionary is.
    private static func same(
        _ record: Record,
        _ dictionary: Value.Dictionary,
        by held: (Value, Value) -> Bool
    ) -> Bool {
        guard record.name == nil, record.count == dictionary.count else { return false }

        return dictionary.entries.indices.allSatisfy { place in
            record.names[place] == dictionary.entries[place].name
                && held(record.values[place], dictionary.entries[place].value)
        }
    }
}
