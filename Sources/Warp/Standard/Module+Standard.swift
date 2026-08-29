//
//  Module+Standard.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

public extension Module {
    // A list rather than one module: these are separate bundles, and a caller
    // takes the ones its programs have use for — together with `foundation`,
    // which holds the constraints the other bundles' signatures mention.
    static let standard: [Module] = [
        .foundation, .logic, .math, .text, .collection, .control, .concurrent
    ]
}
