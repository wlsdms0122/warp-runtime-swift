//
//  Body.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

struct Body: Sendable {
    // MARK: - Property
    let instructions: [Instruction]
    let result: Code?

    // MARK: - Initializer
    init(instructions: [Instruction], result: Code?) {
        self.instructions = instructions
        self.result = result
    }

    // MARK: - Public
    // MARK: - Private
}
