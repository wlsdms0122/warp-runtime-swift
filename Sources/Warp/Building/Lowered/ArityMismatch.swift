//
//  ArityMismatch.swift
//  Warp
//
//  Created by JSilver on 9/24/26.
//

import Foundation

// Why arguments handed by position do not fit a procedure: more of them than
// it takes, or positions left off at the end whose type does not read absence
// as null. Positions and not names, since a value's type carries none; a
// surface that knows the names says them.
enum ArityMismatch: Sendable, Equatable {
    case tooMany(takes: Int)
    case missing(positions: [Int])
}
