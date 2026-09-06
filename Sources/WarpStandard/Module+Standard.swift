//
//  Module+Standard.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

public extension Module {
    // A list rather than one module: these are separate bundles, and a caller
    // takes the ones its programs have use for — together with `foundation`,
    // which holds the constraints the other bundles' signatures mention.
    //
    // Each is written here and checked where it is made, so a refusal from one
    // is this package disagreeing with itself rather than anything a caller
    // did. That is why the seven force the try: there is no caller to hand it
    // to, and a bundle that will not check is a bug in the words shipped with
    // the language.
    static let standard: [Module] = [
        .foundation, .logic, .math, .text, .collection, .control, .concurrent
    ]
}
