//
//  Value+Nesting.swift
//  WarpSyntax
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Warp

// Held by the syntax rather than by the value: how deep a document may nest
// is a fact about the wire.
extension Value {
    // How deep a document may nest. The bound is exact: every reader takes
    // a document within it and refuses the first container past it, and a
    // value a caller built is held to it at the door a document is read at.
    public static let nestingBound = 128

    // How many containers the deepest path through this value opens, counted
    // on a stack of the walk's own: a value handed in is a caller's, and how
    // deep they built it is not this process to spend.
    var nesting: Int {
        var deepest = 0
        var open: [(value: Value, within: Int)] = [(self, 0)]

        while let (value, within) = open.popLast() {
            guard let held = value.held else { continue }

            deepest = max(deepest, within + 1)
            open.append(contentsOf: held.map { _, element in (element, within + 1) })
        }

        return deepest
    }

    // The steps down to the deepest container, for a refusal to stand on. A
    // second walk rather than one carrying steps, since every value read
    // pays for the count and only one past the bound pays for the address.
    var deepest: [Place.Step] {
        var deepest: [Place.Step] = []
        var open: [(value: Value, steps: [Place.Step])] = [(self, [])]

        while let (value, steps) = open.popLast() {
            guard let held = value.held else { continue }

            if steps.count >= deepest.count {
                deepest = steps
            }

            open.append(contentsOf: held.map { step, element in (element, steps + [step]) })
        }

        return deepest
    }

    // What a container holds, by the step that reaches each, and nothing for
    // a value that holds nothing.
    private var held: [(step: Place.Step, value: Value)]? {
        switch self {
        case let .array(elements):
            return elements.enumerated().map { index, element in (.index(index), element) }

        case let .record(record):
            return zip(record.layout.fields, record.values).map { name, value in (.key(name.spelling), value) }

        case let .dictionary(fields):
            return fields.entries.map { entry in (.key(entry.name.spelling), entry.value) }

        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return nil
        }
    }
}
