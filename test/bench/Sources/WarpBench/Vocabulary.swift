//
//  Vocabulary.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation
import Warp
import WarpStandard

// The standard vocabulary held the way a host that brings the same procedures every
// run holds it: the documents compiled once, and laid down once against the
// native code behind them.
//
// Every world here is built against these, so what a figure moves with is the
// world's own procedures rather than the ones it always costs. The documents are
// read back off the laying, so what a build is handed and what it was laid
// against are one thing.
enum Vocabulary {
    static let brought = try! Supplying(Module.standard)

    // Settled once and awaited by everyone who reads it. A compile suspends
    // and a stored property cannot, so what is held here is the settling
    // rather than the answer.
    static let laid = Task {
        try Builder().lay(try await Builder().compile(Module.standard), supplying: brought)
    }
}
