//
//  Keyed.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// The parts of an object, each under its key. The dictionary is held to the
// layout's keys as it is opened, so it names none the layout does not, and a
// key it leaves out is refused where its part is asked for.
struct Keyed {
    // MARK: - Property
    private let written: Value.Dictionary

    // MARK: - Initializer
    init(_ written: Value.Dictionary) throws {
        if let stray = written.keys.first(where: { key in !ObjectLayout.keys.contains { name in key == .string(name.spelling) } }) {
            throw ObjectRefused("'object' writes '\(Rendering(stray).text())', which this reads none of")
        }

        self.written = written
    }

    // MARK: - Public
    func part(_ key: ObjectLayout.Key) throws -> Value {
        guard let part = written[key.name] else {
            throw ObjectRefused("'object' writes no '\(key.name)'")
        }

        return part
    }

    // MARK: - Private
}
