//
//  Resolution.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// What one spelling means in one namespace — or the two ways it can fail to
// mean one thing. The candidates ride along on ambiguity so the surface that
// refuses can name them, and the sentence lives with the surface: a call, a
// slot and a bound each say it in their own words.
enum Resolution: Equatable {
    case resolved(String)
    case unresolved
    case ambiguous([String])
}

extension String {
    // Whether this declared, qualified spelling answers to a written one —
    // the exact name, or the bare name a module qualified. The one matching
    // rule under `Linker.resolution` and everything that reports on it.
    func answers(to name: String) -> Bool {
        self == name || hasSuffix(".\(name)")
    }
}
