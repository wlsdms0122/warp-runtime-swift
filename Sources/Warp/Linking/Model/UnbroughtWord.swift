//
//  UnbroughtWord.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// The stand-in for a word whose code a compile was not handed. A compiled
// document names the words it left to native code and holds none of it, and a
// compile runs one only where it folds a constant through it, so a row nothing
// folds stands here rather than stopping the compile.
//
// A link is another matter: it states what the whole run may call, and a row
// standing like this never reaches one.
struct UnbroughtWord: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    let label: Name

    // MARK: - Initializer
    init(_ label: Name) {
        self.label = label
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        throw ExecutionError(
            "'\(label)' is implemented in native code and this compile was handed none."
                + " A constant folding through it settles from the code the run will use"
        )
    }

    // MARK: - Private
}
