//
//  FanoutReceiver.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The pieces a fan-out is handed: closures under keys, or closures in order.
// Two shapes and no third, which is what the membership says and what `any`
// could not.
enum FanoutReceiver: Int, ParameterSet {
    case of

    // MARK: - Property
    var name: Name { "of" }

    var declared: Parameter { Parameter(type: .named("std.concurrent.Pieces")) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
