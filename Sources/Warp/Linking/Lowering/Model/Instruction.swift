//
//  Instruction.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A statement as the run performs it: what to compute, and which slot takes
// the answer. The label is what a trace calls the statement.
struct Instruction: Sendable {
    enum Binding: Sendable {
        case bind(Int)
        case declare(Int)
        case assign(Int, [Step])
    }

    // MARK: - Property
    let binding: Binding?
    let code: Code
    let label: String

    // MARK: - Initializer
    init(binding: Binding?, code: Code, label: String) {
        self.binding = binding
        self.code = code
        self.label = label
    }

    // MARK: - Public
    // MARK: - Private
}
