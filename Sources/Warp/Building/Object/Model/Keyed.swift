//
//  Keyed.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// The parts of an object, each under its key. The map is held to the
// layout's keys as it is opened, none missing and none the layout does not
// name, so every key hands over its part.
struct Keyed {
    // MARK: - Property
    // In the order the layout declares its keys.
    let parts: [(key: ObjectLayout.Key, value: Value)]

    // MARK: - Initializer
    init(_ value: Value) throws {
        guard case let .dictionary(written) = value else {
            throw ObjectRefused("'object' is not written as a map")
        }

        if let stray = written.keys.first(where: { key in !ObjectLayout.keys.contains { name in key == .string(name.spelling) } }) {
            throw ObjectRefused("'object' writes '\(Rendering(stray).text())', which this reads none of")
        }

        self.parts = try ObjectLayout.Key.allCases.map { key in
            guard let part = written[key.name] else {
                throw ObjectRefused("'object' writes no '\(key.name)'")
            }

            return (key, part)
        }
    }

    // MARK: - Public
    // What stands under a key, asked before the map is held to the layout:
    // what the map says it is decides whether it is an object, and which
    // format, so both are read raw.
    static func peek(_ value: Value, _ key: Name) -> Value? {
        guard case let .dictionary(written) = value else { return nil }

        return written[key]
    }

    // MARK: - Private
}
