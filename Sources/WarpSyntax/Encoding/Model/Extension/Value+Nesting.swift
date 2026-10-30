//
//  Value+Nesting.swift
//  WarpSyntax
//
//  Created by JSilver on 9/17/26.
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
    // a value that holds nothing. A dictionary holds its keys as well as its values,
    // and a key is reached by the step its entry is.
    private var held: [(step: Place.Step, value: Value)]? {
        switch self {
        case let .array(elements):
            return elements.enumerated().map { index, element in (.index(index), element) }

        case let .struct(instance):
            return zip(instance.layout.fields, instance.values).map { name, value in (.key(name.spelling), value) }

        case let .dictionary(held):
            return held.entries.flatMap { entry in
                let step = Place.Step.key(Rendering(entry.key).text())

                return [(step, entry.key), (step, entry.value)]
            }

        case let .existential(existential):
            return existential.value.held

        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            return nil
        }
    }
}
