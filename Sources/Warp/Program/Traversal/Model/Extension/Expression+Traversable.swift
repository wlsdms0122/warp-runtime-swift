//
//  Expression+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Expression: Traversable {
    func walk<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        into found: inout [(Trail, Node)]
    ) {
        // A closure names its own place: the literal and the body it carries
        // are found under one name, so a report says which closure without
        // having to say it twice.
        let here: Trail = if case .closure = self { stepped(trail, to: .closure, by: stepping) } else { trail }

        found.append((here, .expression(self)))

        switch self {
        case .literal, .reference:
            break

        case let .closure(procedure):
            procedure.implementation.body?.walk(at: stepping(here, .part(.body)), stepping: stepping, into: &found)

        case let .cast(value, _, optional):
            walk(value, as: .subject(optional: optional), from: here, stepping: stepping, into: &found)

        case let .leave(leave):
            if let value = leave.value {
                walk(value, as: .held, from: here, stepping: stepping, into: &found)
            }

        case let .array(array):
            for (position, element) in array.enumerated() {
                walk(element, as: .element(position), from: here, stepping: stepping, into: &found)
            }

        case let .struct(literal):
            for (name, field) in literal.sorted(by: { mine, theirs in mine.key < theirs.key }) {
                walk(field, as: .field(name), from: here, stepping: stepping, into: &found)
            }

        // In the order written, each key before its value.
        case let .dictionary(entries):
            for (position, entry) in entries.enumerated() {
                walk(entry.key, as: .entryKey(position), from: here, stepping: stepping, into: &found)
                walk(entry.value, as: .entryValue(position), from: here, stepping: stepping, into: &found)
            }

        // What a call or an application is written with, walked in position
        // order and each given its own place: two of them reported from the
        // same one would say a thing is wrong and not say which.
        case let .apply(callee, written):
            walk(callee, as: .callee, from: here, stepping: stepping, into: &found)

            for (position, argument) in written.enumerated() {
                walk(argument, as: .argument(position), from: here, stepping: stepping, into: &found)
            }

        case let .call(call):
            for (position, argument) in call.arguments.enumerated() {
                walk(argument, as: .argument(position), from: here, stepping: stepping, into: &found)
            }

        case let .conditional(condition, then, otherwise):
            walk(condition, as: .condition(of: .conditional), from: here, stepping: stepping, into: &found)
            then.walk(at: stepped(here, to: .then, by: stepping), stepping: stepping, into: &found)
            otherwise?.walk(at: stepped(here, to: .otherwise, by: stepping), stepping: stepping, into: &found)

        case let .loop(condition, body):
            if let condition {
                walk(condition, as: .condition(of: .loop), from: here, stepping: stepping, into: &found)
            }

            body.walk(at: stepped(here, to: .body, by: stepping), stepping: stepping, into: &found)

        case let .try(tried, `catch`):
            tried.walk(at: stepped(here, to: .body, by: stepping), stepping: stepping, into: &found)
            `catch`.walk(at: stepped(here, to: .catch, by: stepping), stepping: stepping, into: &found)

        case let .unwrap(read, then, otherwise):
            walk(read, as: .unwrapped, from: here, stepping: stepping, into: &found)
            then?.walk(at: stepped(here, to: .then, by: stepping), stepping: stepping, into: &found)
            otherwise?.walk(at: stepped(here, to: .otherwise, by: stepping), stepping: stepping, into: &found)
        }
    }

    // An expression this one holds, walked from where it stands.
    private func walk<Trail>(
        _ expression: Expression,
        as child: Child,
        from here: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        into found: inout [(Trail, Node)]
    ) {
        expression.walk(at: stepped(here, to: child, by: stepping), stepping: stepping, into: &found)
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
