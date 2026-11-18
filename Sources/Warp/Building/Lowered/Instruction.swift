//
//  Instruction.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A statement as the run performs it: what to compute, and which slot takes
// the result.
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

    // MARK: - Initializer
    init(binding: Binding?, code: Operation) {
        self.binding = binding
        self.code = code
    }

    // The slot holding the name the statement was written with: the one its
    // binding lands in or writes through, or the one its construct binds
    // inside itself, a loop's round, a try's failure, an unwrap's payload.
    // Nil for a statement naming nothing. A trace calls a statement by it.
    var naming: Int? {
        switch binding {
        case let .bind(slot)?, let .declare(slot)?:
            return slot

        case let .assign(address)?:
            return address.slot

        case nil:
            return Self.naming(code)
        }
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
            code: try code.rewritten(operation: operation, type: type)
        )
    }

    // MARK: - Private
    // The slot a construct binds inside itself, through what is written
    // around the construct.
    private static func naming(_ code: Operation) -> Int? {
        switch code {
        case let .loop(_, _, round): round
        case let .try(_, _, failure): failure
        case let .unwrap(_, _, _, payload): payload
        case let .coerced(inner, _): naming(inner)
        default: nil
        }
    }
}
