//
//  Record.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// A record's fields, in the byte order of their names: the order the
// canonical writing uses, so a field is found by comparing bytes and no name
// is hashed. The order is the constructor's: whatever a caller hands in, what
// is held is sorted, and one name holds one field. What the name means is
// `Value.record`'s to say.
public struct Record: Sendable {
    // MARK: - Property
    public let name: String?

    // In ascending byte order of `name`, as `Name.precedes` orders them.
    public let entries: [(name: String, value: Value)]

    public var count: Int {
        entries.count
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    public var names: [String] {
        entries.map(\.name)
    }

    public var values: [Value] {
        entries.map(\.value)
    }

    // MARK: - Initializer
    public init(name: String? = nil, _ fields: [String: Value]) {
        self.name = name
        self.entries = fields.map { field in (name: field.key, value: field.value) }
            .sorted { one, other in Name.precedes(one.name, other.name) }
    }

    // Entries in any order, later ones winning over earlier ones of the same
    // name. One entry stands without a comparison.
    public init(name: String? = nil, entries: [(name: String, value: Value)]) {
        self.name = name

        guard entries.count > 1 else {
            self.entries = entries

            return
        }

        var sorted = entries
        sorted.sort { one, other in Name.precedes(one.name, other.name) }

        var held: [(name: String, value: Value)] = []
        held.reserveCapacity(sorted.count)

        for entry in sorted {
            if let last = held.last, Name.same(last.name, entry.name) {
                held[held.count - 1] = entry
            } else {
                held.append(entry)
            }
        }

        self.entries = held
    }

    // Entries already in order under distinct names, for a maker that walks
    // them in order: a literal the link ordered, or another record's
    // entries with their values changed. Every reading of a record stands
    // on this order, so it is checked here rather than trusted: a pass over
    // the names is less than the sort it stands in for.
    init(name: String?, ordered entries: [(name: String, value: Value)]) {
        precondition(
            zip(entries, entries.dropFirst()).allSatisfy { one, other in Name.precedes(one.name, other.name) },
            "a record's entries are ordered by name"
        )

        self.name = name
        self.entries = entries
    }

    // Entries this record already holds, in the order it holds them, for
    // the makers below that change a value, a name or one place and so
    // cannot disturb the order.
    private init(name: String?, keeping entries: [(name: String, value: Value)]) {
        self.name = name
        self.entries = entries
    }

    // MARK: - Public
    // The field of this name, or nil where none is held. A binary search
    // over the names' bytes.
    public subscript(field: String) -> Value? {
        let (position, found) = position(of: field)

        return found ? entries[position].value : nil
    }

    // This record with one field written: the value replaced where the name
    // is held, and the field put where it sorts where it is not.
    public func writing(_ field: String, with value: Value) -> Record {
        var written = entries
        let (position, found) = position(of: field)

        if found {
            written[position].value = value
        } else {
            written.insert((name: field, value: value), at: position)
        }

        return Record(name: name, keeping: written)
    }

    // This record without the field of this name, or as it is where none is
    // held.
    public func removing(_ field: String) -> Record {
        let (position, found) = position(of: field)

        guard found else { return self }

        var written = entries
        written.remove(at: position)

        return Record(name: name, keeping: written)
    }

    // This record with every value put through `transform`, under the same
    // names in the same order, so nothing is sorted or searched.
    public func mapValues(_ transform: (String, Value) throws -> Value) rethrows -> Record {
        Record(
            name: name,
            keeping: try entries.map { entry in (name: entry.name, value: try transform(entry.name, entry.value)) }
        )
    }

    // This record under another name, with the same fields.
    public func named(_ name: String?) -> Record {
        Record(name: name, keeping: entries)
    }

    // MARK: - Private
    // Where a name is, or where it would go: the first position whose name
    // does not precede it, and whether the name there is it.
    private func position(of field: String) -> (Int, Bool) {
        var low = 0
        var high = entries.count

        while low < high {
            let middle = (low + high) / 2

            if Name.precedes(entries[middle].name, field) {
                low = middle + 1
            } else {
                high = middle
            }
        }

        return (low, low < entries.count && Name.same(entries[low].name, field))
    }
}

extension Record: Equatable {
    public static func == (lhs: Record, rhs: Record) -> Bool {
        Name.same(lhs.name, rhs.name)
            && lhs.entries.count == rhs.entries.count
            && zip(lhs.entries, rhs.entries).allSatisfy { one, other in
                Name.same(one.name, other.name) && one.value == other.value
            }
    }
}
