//
//  Value+Nesting.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

extension Value {
    // How many containers the deepest path through this value opens, counted
    // on a stack of the walk's own: a value handed in is a caller's, and how
    // deep they built it is not this process to spend.
    var nesting: Int {
        var deepest = 0
        var open: [(value: Value, within: Int)] = [(self, 0)]

        while let (value, within) = open.popLast() {
            let held: [Value]

            switch value {
            case let .array(elements):
                held = elements

            case let .record(record):
                held = record.asDictionary.entries.map(\.value)

            case let .dictionary(fields):
                held = fields.entries.map(\.value)

            case .null, .bool, .int, .double, .string, .bytes, .procedure:
                continue
            }

            deepest = max(deepest, within + 1)
            open.append(contentsOf: held.map { element in (element, within + 1) })
        }

        return deepest
    }
}
