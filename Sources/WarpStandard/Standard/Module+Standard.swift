//
//  Module+Standard.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

public extension Module {
    // A list rather than one module: these are separate bundles, and a host
    // takes the ones its programs have use for. Together with `sharedGround`,
    // which holds the contracts the other bundles' signatures mention and
    // what satisfies them for the types the language names. Each bundle is a
    // list of its own.
    static let standard: [Module] = sharedGround + logic + math + text + collection + optional + control + concurrent
}
