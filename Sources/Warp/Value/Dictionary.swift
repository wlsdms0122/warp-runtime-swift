//
//  Dictionary.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// Names and values where the names are data: what a document hands in and what
// a word that reads names answers. Which names are here is the value's to say,
// not a declaration's, so each entry carries its own name.
//
// The entries stand in ascending byte order of their names, the order the
// canonical writing uses, and a name is found by comparing bytes.
public struct Dictionary: Sendable {
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

    // The inner door: entries already in order under distinct names.
    init(ordered entries: [(name: Name, value: Value)]) {
        precondition(
            zip(entries, entries.dropFirst()).allSatisfy { one, other in one.name < other.name },
            "a dictionary's entries are ordered by name"
        )

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

extension Dictionary: Equatable {
    public static func == (lhs: Dictionary, rhs: Dictionary) -> Bool {
        lhs.entries.count == rhs.entries.count
            && zip(lhs.entries, rhs.entries).allSatisfy { mine, theirs in
                mine.name == theirs.name && mine.value == theirs.value
            }
    }
}
