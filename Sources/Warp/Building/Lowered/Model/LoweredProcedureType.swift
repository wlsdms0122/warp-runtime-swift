//
//  LoweredProcedureType.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

// A procedure type as the run reads it: the types it is applied with, in
// position order, what it answers, nil where nothing was declared, and what
// may come out of it when the work goes wrong. The lowering of a
// `ProcedureType`, so a slot that writes no signature writes none of them.
struct LoweredProcedureType: Sendable, Equatable {
    // MARK: - Property
    let parameters: [LoweredType]
    let returns: LoweredType?
    let failing: Failing

    // MARK: - Initializer
    init(parameters: [LoweredType], returns: LoweredType?, failing: Failing = .unstated) {
        self.parameters = parameters
        self.returns = returns
        self.failing = failing
    }

    // MARK: - Public
    // The same type with every part rewritten.
    func map(_ part: (LoweredType) throws -> LoweredType) rethrows -> LoweredProcedureType {
        LoweredProcedureType(parameters: try parameters.map(part), returns: try returns.map(part), failing: failing)
    }

    // The same type claiming `failing` instead.
    func claiming(_ failing: Failing) -> LoweredProcedureType {
        LoweredProcedureType(parameters: parameters, returns: returns, failing: failing)
    }

    // Two readings of one procedure type: the same positions and answer,
    // failing with what either may. Nil where the two take or answer apart.
    func joined(_ other: LoweredProcedureType) -> LoweredProcedureType? {
        guard parameters == other.parameters, returns == other.returns else { return nil }

        return claiming(failing.joined(other.failing))
    }

    // MARK: - Private
}
