//
//  Fields.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A mapping of a tree being written as a node, its keys taken one at a time.
// A key left once every node has taken its own is one no node writes.
struct Fields {
    // MARK: - Property
    // What the mapping is, for a refusal to name.
    let place: String

    private var left: [String: Value]

    // MARK: - Initializer
    init(_ value: Value, as place: String) throws {
        self.place = place
        self.left = try Dictionary(uniqueKeysWithValues: Self.entries(value, as: place))
    }

    // MARK: - Public
    mutating func take(_ key: String) -> Value? {
        left.removeValue(forKey: key)
    }

    func finish() throws {
        guard let key = left.keys.sorted().first else { return }

        throw Unplaced("\(place) holds `\(key)`, and no node writes it there")
    }

    // A mapping's entries under the texts that key them, in the key order.
    static func entries(_ value: Value, as place: String) throws -> [(key: String, value: Value)] {
        guard case let .dictionary(held) = value else {
            throw Unplaced("\(place) is a mapping, and here is \(Rendering(value).text())")
        }

        return try held.entries.map { entry in
            guard case let .string(key) = entry.key else {
                throw Unplaced("\(place) is keyed by names, and here holds \(Rendering(entry.key).text())")
            }

            return (key, entry.value)
        }
    }

    static func list(_ value: Value, as place: String) throws -> [Value] {
        guard case let .array(elements) = value else {
            throw Unplaced("\(place) is a list, and here is \(Rendering(value).text())")
        }

        return elements
    }

    static func text(_ value: Value, as place: String) throws -> String {
        guard case let .string(text) = value else {
            throw Unplaced("\(place) is text, and here is \(Rendering(value).text())")
        }

        return text
    }

    // MARK: - Private
}
