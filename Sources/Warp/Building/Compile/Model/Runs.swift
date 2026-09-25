//
//  Runs.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// What makes an expression something the run runs rather than reads.
enum Runs: Sendable {
    case calling(Name)
    case applying
    case construct
}
