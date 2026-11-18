//
//  CompiledBody.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// A written body compiled: its instructions as one block, and its frame laid
// out once, every slot null but the constants it reads, so a call copies the
// slots rather than making them.
final class CompiledBody: Sendable {
    // MARK: - Property
    let block: CompiledBlock
    let cells: [Cell]
    let names: [Name]
    let parameters: [Int]
    let variables: [(variable: Int, slot: Int)]

    // MARK: - Initializer
    init(block: CompiledBlock, frame: Frame) {
        var cells = Array(repeating: Cell.value(.null), count: frame.size)

        for (value, slot) in frame.constants {
            cells[slot] = .value(value)
        }

        self.block = block
        self.cells = cells
        self.names = frame.names
        self.parameters = frame.parameters
        self.variables = frame.variables
    }

    // MARK: - Public
    // The body run as a procedure: what it returns is caught here. The build
    // held every way out to what the body declares, so it is handed on as it
    // came. A body returns through `return`, so one that reaches its end
    // returns null; a `return` standing last in it gives its value as the
    // block's last, and any other is caught.
    //
    // Cancellation is observed on entry, since a run that does not end calls
    // without end or loops, and a loop observes it on every round.
    nonisolated(nonsending) func run(in activation: inout Activation, by evaluator: Evaluator) async throws -> Value {
        try Task.checkCancellation()

        do {
            return try await block.run(&activation, evaluator)
        } catch let Leaving.procedure(value) {
            // A closure is a procedure, so this is also what stops a `return`
            // written inside one from returning for the procedure around it.
            return value
        } catch is Leaving {
            // A loop is inside one body, so one reaching here named a loop no
            // body around it opened. A document is held to naming one the
            // validator can see; an object carries the lowered body and not
            // the document, so what is read back out of a cache never stood in
            // front of that judge.
            //
            // Refused here rather than where a caller happens to stand,
            // because what a frame does at its edge is this function's. Going
            // on would let a loop further out take a leave that was never
            // about it, which reads as a result rather than as a refusal.
            throw RunRefused("a leave reached the frame it started in, and nothing there takes one")
        }
    }

    // The module variables the body reads, each a hold on the run's box in
    // its slot.
    func holdVariables(in cells: inout [Cell], of callee: Linked, by evaluator: Evaluator) throws {
        guard !variables.isEmpty else { return }

        guard evaluator.boxes.indices.contains(callee.origin) else {
            throw RunRefused("'\(callee.rendered)' reads its document's variables, and this run holds none")
        }

        let held = evaluator.boxes[callee.origin]

        for (variable, slot) in variables {
            cells[slot] = .hold(held[variable])
        }
    }

    // MARK: - Private
}
