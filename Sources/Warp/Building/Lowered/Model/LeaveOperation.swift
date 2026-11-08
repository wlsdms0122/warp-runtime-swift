//
//  LeaveOperation.swift
//  Warp
//
//  Created by JSilver on 10/22/26.
//

import Foundation

// A leave as the run takes it, one case per reach, each with its own part:
// the return value a `return` writes, or nothing for null, and the loop a `break` or a
// `continue` names, or nothing for the nearest.
enum LeaveOperation: Sendable {
    case procedure(Operation?)
    case loop(Name?)
    case round(Name?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
