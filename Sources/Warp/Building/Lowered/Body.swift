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
        contains { node in node.reads(slots) }
    }
}

extension Body.Node {
    // Whether this one node reads a slot of the range, apart from what nests
    // in it. A further question over the same shape as `stand`, and it stays
    // apart: this counts only the slots a body's value depends on, and leaves
    // out the ones it binds.
    func reads(_ slots: Range<Int>) -> Bool {
        switch self {
        case let .instruction(instruction):
            guard case let .assign(address, _)? = instruction.binding else { return false }

            return address.reads(slots)

        case let .operation(operation):
            switch operation {
            case let .local(address):
                return address.reads(slots)

            case let .closure(_, captures):
                return captures.contains { outer, _ in slots.contains(outer) }

            case let .call(call):
                return call.handed.contains { handed in handed.address.reads(slots) }

            case let .dispatch(dispatch):
                return dispatch.arguments.contains { argument in
                    guard case let .reference(address) = argument else { return false }

                    return address.reads(slots)
                }

            case .literal, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
                return false
            }
        }
    }
}
