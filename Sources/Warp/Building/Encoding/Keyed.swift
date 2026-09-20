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
    private let part: String
    private let written: Value.Dictionary
    private var taken: Set<Name> = []

    // MARK: - Initializer
    init(_ value: Value, of part: String, keys: Set<Name>) throws {
        guard case let .dictionary(written) = value else {
            throw ObjectRefused("'\(part)' is not written as a record")
        }

        if let stray = written.names.first(where: { name in !keys.contains(name) }) {
            throw ObjectRefused("'\(part)' writes '\(stray)', which this reads none of")
        }

        if let missing = keys.sorted().first(where: { name in written[name] == nil }) {
            throw ObjectRefused("'\(part)' writes no '\(missing)'")
        }

        self.part = part
        self.written = written
    }

    // MARK: - Internal
    // What stands under a key, asked before the record is held to a layout:
    // what the record says it is decides which layout that is, and which
    // format, so both are read raw.
    static func peek(_ value: Value, _ key: Name) -> Value? {
        guard case let .dictionary(written) = value else { return nil }

        return written[key]
    }

    mutating func take(_ key: Name) throws -> Value {
        guard let held = written[key] else {
            throw ObjectRefused("'\(part)' writes no '\(key)'")
        }

        taken.insert(key)

        return held
    }

    // That every key written has been taken. The record was held to the
    // layout's keys when it was opened, so what is left is a part the layout
    // names and this reading forgot, which is this reading's defect and not
    // the object's; it is said here so the pair cannot drift apart quietly.
    func end() throws {
        guard let forgotten = written.names.first(where: { name in !taken.contains(name) }) else { return }

        throw ObjectRefused("'\(part)' writes '\(forgotten)', which this reading left unread")
    }
}
