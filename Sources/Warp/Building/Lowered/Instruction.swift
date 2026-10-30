//
//  Instruction.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A statement as the run performs it: what to compute, and which slot takes
// the result. The label is what a trace calls the statement.
struct Instruction: Sendable {
    // How a slot takes the result: a name bound, a box declared, or a box
    // written through an address. The build held what lands there to what
    // the name holds, so it lands as it came.
    enum Binding: Sendable {
        case bind(Int)
        case declare(Int)
        case assign(Address)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func rewritten(type: (LoweredType) throws -> LoweredType) rethrows -> Binding {
            guard case let .assign(address) = self else { return self }

            return .assign(try address.rewritten(type: type))
        }

        // MARK: - Private
    }

    // MARK: - Property
    let binding: Binding?
    let code: Operation
    let label: String

    // MARK: - Initializer
    init(binding: Binding?, code: Operation, label: String) {
        self.binding = binding
        self.code = code
        self.label = label
    }

    // MARK: - Public
    @discardableResult
    func walk(_ visit: (LoweredBody.Node) -> Bool) -> Bool {
        visit(.instruction(self)) && code.walk(visit)
    }

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

    // MARK: - Private
}

