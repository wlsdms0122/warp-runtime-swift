//
//  Constness.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Whether a procedure is const. A declaration says it of
// itself and a slot asks it of what stands in it: a procedure that runs its
// argument inside a condition or a path needs an argument that can be run
// there, and `Procedure` alone does not say so.
public enum Constness: Sendable, Equatable {
    // No claim. Either kind fits, the way `Any` fits any value.
    case unstated

    // Must be const. What stands here may be asked wherever a
    // value is read rather than run.
    case const
}
