//
//  TableWriting.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// One of an object's tables as it is written. An entry is numbered when it is
// finished, after everything it holds, so every number an entry holds points
// to one before it.
final class TableWriting {
    // MARK: - Property
    private(set) var entries: [Value] = []

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // The number the entry stands at, which is what is written where it is
    // held.
    func number(_ entry: Value) -> Value {
        entries.append(entry)

        return .int(entries.count - 1)
    }

    // MARK: - Private
}
