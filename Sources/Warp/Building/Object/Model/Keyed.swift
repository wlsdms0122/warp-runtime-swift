//
//  Keyed.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// The parts of an object, each under its key. The record is held to the
// layout's keys as it is opened, none missing and none the layout does not
// name, so a part asked for afterwards is there.
struct Keyed {
    // MARK: - Property
    private let written: Value.Dictionary

    // MARK: - Initializer
    init(_ value: Value) throws {
        guard case let .dictionary(written) = value else {
            throw ObjectRefused("'object' is not written as a record")
        }

        if let stray = written.names.first(where: { name in !ObjectLayout.keys.contains(name) }) {
            throw ObjectRefused("'object' writes '\(stray)', which this reads none of")
        }

        if let missing = ObjectLayout.keys.sorted().first(where: { name in written[name] == nil }) {
            throw ObjectRefused("'object' writes no '\(missing)'")
        }

        self.written = written
    }

    // MARK: - Public
    // What stands under a key, asked before the record is held to the layout:
    // what the record says it is decides whether it is an object, and which
    // format, so both are read raw.
    static func peek(_ value: Value, _ key: Name) -> Value? {
        guard case let .dictionary(written) = value else { return nil }

        return written[key]
    }

    func take(_ key: ObjectLayout.Key) throws -> Value {
        guard let held = written[key.name] else {
            throw ObjectRefused("'object' writes no '\(key.name)'")
        }

        return held
    }

    // MARK: - Private
}
