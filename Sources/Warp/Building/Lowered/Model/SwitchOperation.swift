//
//  SwitchOperation.swift
//  Warp
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// A switch as the run makes it: what it takes apart, the enum it takes a
// value of by its bare name, an arm per case it names in the order of their
// names, and what runs for a case no arm names. A value the enum carries is a
// struct under a case's spelling, so the arm it takes is the one whose case
// the enum's name spells it as.
struct SwitchOperation: Sendable {
    // MARK: - Property
    let subject: Operation
    let enumeration: Name
    let arms: [LoweredArm]

    // Nil where the switch writes no `default`, and empty where its `default`
    // holds nothing.
    let `default`: [Instruction]?

    private let spelled: [Name: LoweredArm]

    // MARK: - Initializer
    // The same, where the arms were read apart and their order is what has
    // to be true. The unchecked initializer is reached with an order this
    // proved.
    init(subject: Operation, enumeration: Name, judging arms: [LoweredArm], default: [Instruction]?) throws {
        guard arms.map(\.name).ordered else {
            throw ObjectRefused("a switch writes its arms out of name order, or one case twice")
        }

        self.init(subject: subject, enumeration: enumeration, arms: arms, default: `default`)
    }

    // The unchecked initializer: the maker already stands on the order.
    init(subject: Operation, enumeration: Name, arms: [LoweredArm], default: [Instruction]?) {
        assert(arms.map(\.name).ordered, "a switch holds its arms in the order of their cases' names, none twice")

        self.subject = subject
        self.enumeration = enumeration
        self.arms = arms
        self.default = `default`
        self.spelled = Dictionary(
            arms.map { arm in (arm.name.spelled(under: enumeration), arm) },
            uniquingKeysWith: { one, _ in one }
        )
    }

    // MARK: - Public
    // The arm a value of the enum takes, or nil where no arm names its case.
    func arm(for instance: Struct) -> LoweredArm? {
        spelled[instance.name]
    }

    // The same switch with every operation and every type in it replaced.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> SwitchOperation {
        SwitchOperation(
            subject: try subject.rewritten(operation: operation, type: type),
            enumeration: enumeration,
            arms: try arms.map { arm in try arm.rewritten(operation: operation, type: type) },
            default: try `default`.map { instructions in
                try instructions.map { instruction in try instruction.rewritten(operation: operation, type: type) }
            }
        )
    }

    // MARK: - Private
}
