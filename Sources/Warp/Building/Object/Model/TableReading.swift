//
//  TableReading.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// One of an object's tables as it is read. Every entry is held in one place
// and read from there, after everything it holds, so the entry a reading
// finishes is always the next one. An entry finished at another number,
// held twice or held nowhere is a writing of another object, and refused.
final class TableReading {
    // MARK: - Property
    private let part: String
    private let entries: [Value]
    private var next = 0
    private var opened: Set<Int> = []

    // MARK: - Initializer
    init(_ entries: [Value] = [], of part: String) {
        self.part = part
        self.entries = entries
    }

    convenience init(written value: Value, of part: String) throws {
        self.init(try Field(value, of: part).list { entry in entry }, of: part)
    }

    // MARK: - Public
    // The entry a number stands for, held here. What reads it hands the
    // number back to `finish` once everything the entry holds is read.
    func open(_ number: Value) throws -> (number: Int, entry: Value) {
        let number = try Field(number, of: part).count()

        guard number < entries.count else {
            throw ObjectRefused("'\(part)' holds \(entries.count) entries, and \(number) is none of them")
        }

        guard number >= next, opened.insert(number).inserted else {
            throw ObjectRefused("'\(part)' entry \(number) is held twice, and every entry is held once")
        }

        return (number, entries[number])
    }

    // That the entry read is the next one.
    func finish(_ number: Int) throws {
        guard number == next else {
            throw ObjectRefused(
                "'\(part)' writes entry \(number) where \(next) is read next, and an entry stands right after what it holds"
            )
        }

        next += 1
    }

    // That every entry was held somewhere.
    func end() throws {
        guard next == entries.count else {
            throw ObjectRefused("'\(part)' holds \(entries.count - next) entries nothing holds")
        }
    }

    // MARK: - Private
}
