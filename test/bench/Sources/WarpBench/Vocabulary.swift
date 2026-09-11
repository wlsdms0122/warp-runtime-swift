//
//  Vocabulary.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation
import Warp
import WarpStandard

// The standard vocabulary held the way a host that brings the same words every
// run holds it: the documents compiled once, and the native code behind them
// joined up once.
//
// Every world here is built against these, so what a figure moves with is the
// world's own words rather than the ones it always costs.
enum Vocabulary {
    static let compiled = try! Builder().compile(Module.standard)
    static let brought = try! Supplying(Module.standard)

    // The same documents laid down: the rows they stand as, made once. A host
    // that brings the same words every run holds this and hands it over
    // rather than having them made again at every build.
    static let laid = try! Builder().lay(compiled, supplying: brought)
}
