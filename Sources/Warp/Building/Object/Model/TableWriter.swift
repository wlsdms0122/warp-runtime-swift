//
//  TableWriter.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// One of an object's tables as it is written. An entry is opened before
// everything it holds and appended after, so every number an entry holds
// points to one before it, and entries nest no deeper than a written tree
// may.
final class TableWriter {
    // MARK: - Property
    private let key: ObjectLayout.Key
    private(set) var entries: [Value] = []
    private var opened = 0

    // MARK: - Initializer
    init(of key: ObjectLayout.Key) {
        self.key = key
    }

    // MARK: - Public
    func open() throws(ObjectUnwritable) {
        guard opened < Value.nestingBound else {
            throw ObjectUnwritable("'\(key.rawValue)' entries nest deeper than \(Value.nestingBound) levels, and a written tree nests no deeper")
        }

        opened += 1
    }

    // The number the entry stands at, which is what is written where it is
    // held.
    func append(_ entry: Value) -> Value {
        opened -= 1
        entries.append(entry)

        return .int(entries.count - 1)
    }

    // MARK: - Private
}
