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
    let result: Operation?

    // MARK: - Initializer
    init(instructions: [Instruction], result: Operation?) {
        self.instructions = instructions
        self.result = result
    }

    // MARK: - Public
    // MARK: - Private
}

extension Body {
    func reads(_ slots: Range<Int>) -> Bool {
        instructions.contains { instruction in instruction.reads(slots) }
            || result?.reads(slots) == true
    }
}
