//
//  LoweredParameter.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// A parameter as a lowered procedure type holds it: its name, its type
// lowered, and whether the declaration wrote a default. Whether a call must
// fill it is asked of these two and the table, since a type declaring null
// is read off the row it names, and a row is the table's to answer.
struct LoweredParameter: Equatable, Sendable {
    // MARK: - Property
    let name: Name
    let type: LoweredType
    let defaulted: Bool

    // MARK: - Initializer
    init(name: Name, type: LoweredType, defaulted: Bool) {
        self.name = name
        self.type = type
        self.defaulted = defaulted
    }

    // MARK: - Public
    // Whether a call must write this parameter, which is the type's answer
    // given whether a default stands.
    func mustBeGiven(in table: LoweredTypeTable) -> Bool {
        type.mustBeGiven(defaulted: defaulted, in: table)
    }

    // MARK: - Private
}
