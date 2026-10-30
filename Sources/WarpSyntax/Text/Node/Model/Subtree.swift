//
//  Subtree.swift
//  WarpSyntax
//
//  Created by JSilver on 10/21/26.
//

import Foundation
import Warp

// A part of a tree being written as a node, read as the shape the node writes
// it in. A part of another shape is refused under the place it stands at.
struct Subtree {
    // MARK: - Property
    private let value: Value

    // What the part is, for a refusal to name.
    private let place: String

    // MARK: - Initializer
    init(_ value: Value, as place: String) {
        self.value = value
        self.place = place
    }

    // MARK: - Public
    // A mapping's entries under the strings that key them, in the key order.
    func entries() throws -> [(key: String, value: Value)] {
        guard case let .dictionary(held) = value else {
            throw TextRefused("\(place) is a mapping, and here is \(Rendering(value).text())")
        }

        return try held.entries.map { entry in
            guard case let .string(key) = entry.key else {
                throw TextRefused("\(place) is keyed by names, and here holds \(Rendering(entry.key).text())")
            }

            return (key, entry.value)
        }
    }

    func list() throws -> [Value] {
        guard case let .array(elements) = value else {
            throw TextRefused("\(place) is a list, and here is \(Rendering(value).text())")
        }

        return elements
    }

    func string() throws -> String {
        guard case let .string(string) = value else {
            throw TextRefused("\(place) is a string, and here is \(Rendering(value).text())")
        }

        return string
    }

    // MARK: - Private
}
