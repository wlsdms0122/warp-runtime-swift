//
//  Expression+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Expression: Traversable {
    func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        // A closure names its own place: the literal and the body it carries
        // are found under one name, so a report says which closure without
        // having to say it twice.
        let here: Trail = if case .closure = self { stepped(trail, to: .closure, by: stepping) } else { trail }

        func inner(_ expression: Expression, as child: Child) -> [(Trail, Node)] {
            expression.walked(at: stepped(here, to: child, by: stepping), stepping: stepping)
        }

        let held: [(Trail, Node)] = switch self {
        case .literal, .reference:
            []

        case let .closure(procedure):
            procedure.block?.walked(at: here, stepping: stepping) ?? []

        case let .cast(value, _, optional):
            inner(value, as: .subject(optional: optional))

        case let .leave(leave):
            leave.value.map { value in inner(value, as: .held) } ?? []

        case let .array(array):
            array.enumerated().flatMap { position, element in inner(element, as: .element(position)) }

        case let .record(record):
            record.sorted { mine, theirs in mine.key < theirs.key }
                .flatMap { name, field in inner(field, as: .field(name)) }

        // In the order written, each key before its value.
        case let .dictionary(entries):
            entries.enumerated().flatMap { position, entry in
                inner(entry.key, as: .entryKey(position)) + inner(entry.value, as: .entryValue(position))
            }

        // What a call or an application is written with, walked in position
        // order and each given its own place: two of them reported from the
        // same one would say a thing is wrong and not say which.
        case let .apply(callee, written):
            inner(callee, as: .callee)
                + written.enumerated().flatMap { position, argument in inner(argument, as: .argument(position)) }

        case let .call(call):
            call.arguments.enumerated().flatMap { position, argument in inner(argument, as: .argument(position)) }

        case let .block(block):
            block.walked(at: stepped(here, to: .held, by: stepping), stepping: stepping)

        case let .conditional(condition, then, otherwise):
            inner(condition, as: .condition(of: .conditional))
                + then.walked(at: stepped(here, to: .then, by: stepping), stepping: stepping)
                + (otherwise?.walked(at: stepped(here, to: .otherwise, by: stepping), stepping: stepping) ?? [])

        case let .loop(condition, body):
            inner(condition, as: .condition(of: .loop))
                + body.walked(at: stepped(here, to: .held, by: stepping), stepping: stepping)

        case let .attempt(attempted, rescue):
            attempted.walked(at: stepped(here, to: .held, by: stepping), stepping: stepping)
                + rescue.walked(at: stepped(here, to: .rescue, by: stepping), stepping: stepping)
        }

        return [(here, .expression(self))] + held
    }

    // Where a child stands from the trail of the expression holding it.
    private func stepped<Trail>(
        _ trail: Trail,
        to child: Child,
        by stepping: (Trail, Place.Step) -> Trail
    ) -> Trail {
        child.steps.reduce(trail, stepping)
    }
}
