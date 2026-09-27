//
//  Instruction.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A statement as the run performs it: what to compute, and which slot takes
// the answer. The label is what a trace calls the statement.
struct Instruction: Sendable {
    // What a slot takes, and the type it takes it as. A name that said what
    // it holds carries that type here, so the boundary a declaration is gets
    // crossed the way a parameter's does; a name that said nothing carries
    // none, and what the link worked out for it needs no crossing.
    enum Binding: Sendable {
        case bind(Int, settling: LoweredType?)
        case declare(Int, settling: LoweredType?)
        case assign(Address, settling: LoweredType?)

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
    func walk(_ visit: (Body.Node) -> Bool) -> Bool {
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

