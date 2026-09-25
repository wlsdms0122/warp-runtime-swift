//
//  Body+Rewriting.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// The same code with every operation and every type in it replaced, innermost
// first: an operation is handed over with what nests in it already rewritten.
// Which numbers a relocation answers is its own to say, node by node; how the
// code nests is said by each kind of node rewriting what it holds.
extension Body {
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Body {
        Body(
            instructions: try instructions.map { instruction in
                try instruction.rewritten(operation: operation, type: type)
            },
            result: try result.map { result in try result.rewritten(operation: operation, type: type) }
        )
    }
}
