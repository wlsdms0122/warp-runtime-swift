//
//  Lookup.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

// The walk's answer as the tests ask it: what a path holds, or why the
// reading went wrong.
enum Lookup: Equatable {
    case found(Value)
    case unfit(reason: String)
}
