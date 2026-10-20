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
        self.left = try Dictionary(uniqueKeysWithValues: Subtree(value, as: place).entries())
    }

    // MARK: - Public
    mutating func take(_ key: String) -> Value? {
        left.removeValue(forKey: key)
    }

    func finish() throws {
        guard let key = left.keys.sorted().first else { return }

        throw TextRefused("\(place) holds `\(key)`, and no node writes it there")
    }

    // MARK: - Private
}
