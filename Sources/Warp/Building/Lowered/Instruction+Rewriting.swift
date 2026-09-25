//
//  Instruction+Rewriting.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Instruction {
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Instruction {
        Instruction(
            binding: try binding.map { binding in try binding.rewritten(type: type) },
            code: try code.rewritten(operation: operation, type: type),
            label: label
        )
    }
}

extension Instruction.Binding {
    func rewritten(type: (LoweredType) throws -> LoweredType) rethrows -> Instruction.Binding {
        switch self {
        case let .bind(slot, settling):
            return .bind(slot, settling: try settling.map(type))

        case let .declare(slot, settling):
            return .declare(slot, settling: try settling.map(type))

        case let .assign(address, settling):
            return .assign(address, settling: try settling.map(type))
        }
    }
}
