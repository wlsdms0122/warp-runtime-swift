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
    // takes the ones its programs have use for. Together with `foundation`,
    // which holds the contracts the other bundles' signatures mention and
    // what answers them for the types the language names. Each bundle is a
    // list of its own, under `bundled`.
    static let standard: [Module] = foundation + logic + math + text + collection + control + concurrent
}
