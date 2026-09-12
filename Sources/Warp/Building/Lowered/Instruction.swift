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
    // What a slot takes, and the shape it takes it as. A name that said what
    // it holds carries that shape here, so the boundary a declaration is gets
    // crossed the way a parameter's does; a name that said nothing carries
    // none, and what the link worked out for it needs no crossing.
    enum Binding: Sendable {
        case bind(Int, settling: LoweredType?)
        case declare(Int, settling: LoweredType?)
        case assign(Address, settling: LoweredType?)
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
    // MARK: - Private
}

extension Instruction {
    func reads(_ slots: Range<Int>) -> Bool {
        if case let .assign(address, _)? = binding, address.reads(slots) {
            return true
        }

        return code.reads(slots)
    }
}
