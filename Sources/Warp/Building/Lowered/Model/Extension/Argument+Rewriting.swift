//
//  Argument+Rewriting.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Argument {
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Argument {
        switch self {
        case let .value(held):
            return .value(try held.rewritten(operation: operation, type: type))

        case .reference:
            return self
        }
    }
}
