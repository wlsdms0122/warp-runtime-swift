//
//  Keyed.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// The mapping a node's parts write, a key at a time: a value under a key, an
// element appended to a list under a key, or an entry under a name in a map
// under a key. A key or a name written twice is refused, since two values
// under one key are two trees and not one tree laid out twice.
struct Keyed {
    // MARK: - Property
    private var values: [String: Value] = [:]
    private var lists: [String: [Value]] = [:]
    private var maps: [String: [String: Value]] = [:]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    mutating func write(_ value: Value, under key: String, at offset: Int?) throws {
        guard values.updateValue(value, forKey: key) == nil else {
            throw TextRefused("`\(key)` is written twice", at: offset)
        }
    }

    mutating func append(_ value: Value, under key: String) {
        lists[key, default: []].append(value)
    }

    // A list written whether or not anything is appended to it.
    mutating func hold(_ key: String) {
        if lists[key] == nil {
            lists[key] = []
        }
    }

    mutating func write(_ value: Value, named name: String, under key: String, at offset: Int?) throws {
        guard maps[key, default: [:]].updateValue(value, forKey: name) == nil else {
            throw TextRefused("'\(name)' is written twice", at: offset)
        }
    }

    // A map written whether or not anything is entered in it.
    mutating func holdMap(_ key: String) {
        if maps[key] == nil {
            maps[key] = [:]
        }
    }

    func value() throws -> Value {
        var entries = values.map { key, value in (key: Value.string(key), value: value) }

        entries += lists.map { key, list in (key: Value.string(key), value: Value.array(list)) }
        entries += try maps.map { key, map in
            let held = try Value.Dictionary(map.map { name, value in (key: Value.string(name), value: value) })

            return (key: Value.string(key), value: Value.dictionary(held))
        }

        return .dictionary(try Value.Dictionary(entries))
    }

    // MARK: - Private
}
