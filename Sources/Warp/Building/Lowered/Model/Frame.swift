//
//  Frame.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// How a body's frame is laid out: how many slots, which of them the
// parameters fill in parameter order, which module variables it reads and
// where, the constants it reads at an index the run reads, each folded and
// held in its slot from the body's start, in slot order, which slots a
// closure fills from what it took with it, and what each slot was called,
// for a refusal that names it.
struct Frame: Sendable {
    // MARK: - Property
    let size: Int
    let parameters: [Int]
    let variables: [(variable: Int, slot: Int)]
    let constants: [(value: Value, slot: Int)]
    let captures: [Int]
    let names: [Name]

    // MARK: - Initializer
    init(
        size: Int,
        parameters: [Int],
        variables: [(variable: Int, slot: Int)],
        constants: [(value: Value, slot: Int)],
        captures: [Int],
        names: [Name]
    ) {
        self.size = size
        self.parameters = parameters
        self.variables = variables
        self.constants = constants
        self.captures = captures
        self.names = names
    }

    // MARK: - Public
    // The same frame with every constant's value replaced, the way a link
    // resolves the closures a value holds.
    func rewritten(value rewrite: (Value) throws -> Value) rethrows -> Frame {
        Frame(
            size: size,
            parameters: parameters,
            variables: variables,
            constants: try constants.map { value, slot in (value: try rewrite(value), slot: slot) },
            captures: captures,
            names: names
        )
    }

    // The same frame with every constant's value that holds a type beside it
    // read again, since a type stands numbered in one table.
    func rereadingHeldValues(_ read: (Value) -> Value) -> Frame {
        guard constants.contains(where: { value, _ in value.holdsExistential }) else { return self }

        return rewritten(value: read)
    }

    // Whether these are exactly the slots a closure fills from what it took
    // with it: no fewer, since a cell left out reads as null, and none
    // other, since a slot a parameter or a variable fills is not one a
    // closure took. Asked of a closure literal where an object is read and
    // of a closure value where a link resolves it, so the two ask alike.
    func fills(_ slots: [Int]) -> Bool {
        slots.count == captures.count && Set(slots) == Set(captures)
    }

    // MARK: - Private
}
