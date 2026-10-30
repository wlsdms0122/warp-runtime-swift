//
//  CallOperation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A call to the declaration a document named, as the run makes it: the call
// placed against the row it reaches, and what fills the callee's type
// parameters.
struct CallOperation: Sendable {
    // MARK: - Property
    let placed: PlacedCall

    // What fills each type parameter of the callee, in the order the callee
    // names them, as the build wrote it: a type, which may name a type
    // parameter of the body the call stands in, read there by what the run
    // holds for it.
    let types: [LoweredType]

    // MARK: - Initializer
    init(placed: PlacedCall, types: [LoweredType]) {
        self.placed = placed
        self.types = types
    }

    // MARK: - Public
    // The same call with every argument it writes and every type it hands
    // rewritten.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> CallOperation {
        CallOperation(placed: try placed.rewritten(operation: operation, type: type), types: try types.map(type))
    }

    // MARK: - Private
}
