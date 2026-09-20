//
//  Isolation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Whether a procedure touches no name that another body could touch at the same
// time: it writes no module variable, hands none to an `inout`, calls only
// isolated procedures and calls no value. A closure adds one more: it writes
// nothing it captured. What is isolated may run beside anything.
//
// Two-valued like `Constness`, and for the same reason: a slot asks for isolation
// or says nothing, and no slot asks for the lack of it.
public enum Isolation: Sendable, Equatable {
    case unstated
    case isolated
}
