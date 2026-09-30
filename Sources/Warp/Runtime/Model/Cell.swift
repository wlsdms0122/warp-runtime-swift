//
//  Cell.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// What a frame slot holds: a value bound under a name, or a hold on a
// variable. A hold is a `var` declared here, a parameter handed in place, or
// a module variable; reading through it reads the box, writing through it
// writes the box.
enum Cell: Sendable {
    case value(Value)
    case hold(Handle)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The slot's value, read through the hold where it is one.
    func value() throws -> Value {
        switch self {
        case let .value(value):
            return value

        case let .hold(handle):
            return try handle.value()
        }
    }

    // MARK: - Private
}
