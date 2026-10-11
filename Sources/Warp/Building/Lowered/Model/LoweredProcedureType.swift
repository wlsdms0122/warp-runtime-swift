//
//  LoweredProcedureType.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

// A procedure type as the run reads it: the types it is applied with, in
// position order, and what it answers, nil where nothing was declared. The
// lowering of a `ProcedureType`, so a slot that writes no signature writes
// neither part.
struct LoweredProcedureType: Sendable, Equatable {
    // MARK: - Property
    let parameters: [LoweredType]
    let returns: LoweredType?

    // MARK: - Initializer
    init(parameters: [LoweredType], returns: LoweredType?) {
        self.parameters = parameters
        self.returns = returns
    }

    // MARK: - Public
    // The same type with every part rewritten.
    func map(_ part: (LoweredType) throws -> LoweredType) rethrows -> LoweredProcedureType {
        LoweredProcedureType(parameters: try parameters.map(part), returns: try returns.map(part))
    }

    // MARK: - Private
}
