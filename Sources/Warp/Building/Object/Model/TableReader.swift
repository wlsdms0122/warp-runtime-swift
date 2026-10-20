//
//  TableReader.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// One of an object's tables as it is read. Every entry is held in one place
// and read from there, after everything it holds, so the entry a reading
// closes is always the next one, and every entry an open one holds stands
// before it. An entry closed at another number, held twice or held nowhere
// is a writing of another object, and refused, and so are entries nesting
// deeper than a written tree may.
final class TableReader {
    // MARK: - Property
    private let key: ObjectLayout.Key
    private let entries: [Value]
    private var next = 0
    private var opened: [Int] = []

    // MARK: - Initializer
    init(written value: Value, of key: ObjectLayout.Key) throws {
        self.key = key
        self.entries = try Field(value, of: key.rawValue).list { entry in entry }
    }

    // MARK: - Public
    // The entry a number stands for. What reads it closes it once everything
    // the entry holds is read.
    func open(_ number: Value) throws -> Value {
        let number = try Field(number, of: key.rawValue).count()

        guard number < entries.count else {
            throw ObjectRefused("'\(key.rawValue)' holds \(entries.count) entries, and \(number) is none of them")
        }

        guard number >= next, number < (opened.last ?? entries.count) else {
            throw ObjectRefused("'\(key.rawValue)' entry \(number) is held twice, or by an entry it does not stand before")
        }

        guard opened.count < Value.nestingBound else {
            throw ObjectRefused("'\(key.rawValue)' entries nest deeper than \(Value.nestingBound) levels, and a written tree nests no deeper")
        }

        opened.append(number)

        return entries[number]
    }

    // That the entry read is the next one.
    func close() throws {
        guard let number = opened.popLast(), number == next else {
            throw ObjectRefused(
                "'\(key.rawValue)' writes an entry where \(next) is read next, and an entry stands right after what it holds"
            )
        }

        next += 1
    }

    // That every entry was held somewhere.
    func end() throws {
        guard next == entries.count else {
            throw ObjectRefused("'\(key.rawValue)' holds \(entries.count - next) entries nothing holds")
        }
    }

    // MARK: - Private
}
