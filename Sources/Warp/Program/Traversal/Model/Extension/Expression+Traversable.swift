//
//  Expression+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Expression: Traversable {
    public func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        // A closure names its own place: the literal and the body it carries
        // are found under one name, so a report says which closure without
        // having to say it twice.
        let here: Trail = if case .closure = self { stepping(trail, .part(.closure)) } else { trail }

        func inner(_ expression: Expression, under part: Place.Part? = nil) -> [(Trail, Node)] {
            expression.walked(
                at: part.map { part in stepping(here, .part(part)) } ?? here,
                stepping: stepping
            )
        }

        // What a call or an application is written with, walked in position
        // order and each given its own place: two of them reported from the
        // same one would say a thing is wrong and not say which.
        func arguments(_ children: [Expression]) -> [(Trail, Node)] {
            children.enumerated().flatMap { position, argument in
                argument.walked(at: stepping(stepping(here, .part(.arguments)), .index(position)), stepping: stepping)
            }
        }

        func named(_ children: [Name: Expression], under place: Trail) -> [(Trail, Node)] {
            children.sorted { mine, theirs in mine.key < theirs.key }
                .flatMap { name, child in
                    child.walked(at: stepping(place, .key(name.spelling)), stepping: stepping)
                }
        }

        let held: [(Trail, Node)] = switch self {
        case .literal, .reference:
            []

        case let .closure(procedure):
            procedure.block?.walked(at: here, stepping: stepping) ?? []

        case let .cast(value, _, optional):
            inner(value, under: .subject(optional: optional))

        // A leave writes what it carries directly under its own construct,
        // which the statement holding it already stepped into.
        case let .leave(leave):
            leave.value.map { value in inner(value) } ?? []

        case let .array(array):
            array.enumerated().flatMap { position, element in
                element.walked(at: stepping(here, .index(position)), stepping: stepping)
            }

        case let .record(record):
            named(record, under: stepping(here, .part(.fields)))

        case let .apply(callee, written):
            inner(callee, under: .callee) + arguments(written)

        case let .call(call):
            arguments(call.arguments)

        case let .block(block):
            block.walked(at: here, stepping: stepping)

        case let .conditional(condition, then, otherwise):
            inner(condition, under: .condition(of: .conditional))
                + then.walked(at: stepping(here, .part(.then)), stepping: stepping)
                + (otherwise?.walked(at: stepping(here, .part(.otherwise)), stepping: stepping) ?? [])

        case let .loop(condition, body, _):
            inner(condition, under: .condition(of: .loop))
                + body.walked(at: here, stepping: stepping)

        case let .attempt(attempted, rescue, _):
            attempted.walked(at: here, stepping: stepping)
                + rescue.walked(at: stepping(here, .part(.rescue)), stepping: stepping)
        }

        return [(here, .expression(self))] + held
    }
}
