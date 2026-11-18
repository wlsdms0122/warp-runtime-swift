//
//  CompiledPath.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A slot path read, compiled. A path through fields the build laid out is
// walked here; anything it does not land on, and every other path, is read
// the one way a frame reads a path, which says why it did not land.
final class CompiledPath: Sendable {
    // MARK: - Property
    let address: Address

    // The positions of the fields the path walks, where every step is a field
    // the build laid out and none is marked.
    let fields: [Int]?

    // MARK: - Initializer
    init(_ address: Address) {
        self.address = address
        self.fields = Self.fields(of: address.steps)
    }

    // MARK: - Public
    // Out of line, so the code reading an argument stays as small as a read
    // of a slot.
    @inline(never)
    func read(_ activation: Activation) throws -> Value {
        guard let fields, let landed = Self.walk(activation.cells[address.slot], through: fields) else {
            return try activation.value(at: address)
        }

        return address.promoted ? landed.asSome : landed
    }

    // MARK: - Private
    private static func fields(of steps: [Step]) -> [Int]? {
        var fields: [Int] = []

        for step in steps {
            guard case let .field(position, _, optional: false) = step else { return nil }

            fields.append(position)
        }

        return fields
    }

    // The value at the end of a path of fields, or nil where a step meets
    // anything but a struct holding the field.
    private static func walk(_ cell: Cell, through fields: [Int]) -> Value? {
        var current: Value

        switch cell {
        case let .value(value):
            current = value

        case let .hold(handle):
            guard let value = try? handle.value() else { return nil }

            current = value
        }

        for position in fields {
            guard case let .struct(instance) = current, !instance.isSome, instance.values.indices.contains(position) else {
                return nil
            }

            current = instance.values[position]
        }

        return current
    }
}
