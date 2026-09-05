//
//  Expression+Buried.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// One walk over everything an expression holds, for every stage that has to
// see all of it.
//
// Three of them ask for exactly this and differ only in what they keep: the
// declaration scan wants the closure literals a body buries, the same scan
// wants the shapes its casts name, and the check wants the selectors a module
// sends. Written out per collector, one shape of the language is
// written three times — and a case added to `Expression` reaches whichever
// copies somebody remembered.
//
// Where a thing was found is the caller's to name. A stage that reports has a
// place to extend, and a stage that only gathers has nothing to carry — so
// where a thing is travels as a value the caller hands in, along with how to
// step into one, and the caller wanting nowhere hands in nothing.
//
// A step is a `Place.Step` rather than a word, because a statement is found by
// its name and by its position and only one of those is always there. Handing
// the step over whole is what lets a caller keep both; a word would have made
// this walk choose between them on every stage's behalf.

// What can be walked for everything it holds. Three types answer it, and the
// convenient ways to ask are written once here rather than three times
// over — the same duplication this file exists to remove, at the smaller
// scale where it is easy not to notice.
//
// What a stage keeps is its own. A statement and an expression are offered as
// the walk reaches them, so a stage after types a name declares and a stage
// after the shapes a cast names take the same walk and keep different things.
public protocol Burying {
    func buried<Trail, Found>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        keepingStatement: (Trail, Statement) -> [(Trail, Found)],
        keepingExpression: (Trail, Expression) -> [(Trail, Found)]
    ) -> [(Trail, Found)]
}

public extension Burying {
    // Every expression held in here, each with where it was found.
    func buried<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Expression)] {
        buried(
            at: trail,
            stepping: stepping,
            keepingStatement: { _, _ in [] },
            keepingExpression: { trail, expression in [(trail, expression)] }
        )
    }

    // The walk a stage that reports takes.
    func buried(at place: Place) -> [(Place, Expression)] {
        buried(at: place) { place, step in place.appending(step) }
    }

    // The walk a stage that only gathers takes. Nothing is carried, so nothing
    // is spelled.
    var buried: [Expression] {
        buried(at: ()) { _, _ in () }.map(\.1)
    }

    // Every type a name in here says it holds, each with where it was said.
    func declaring(at place: Place) -> [(Place, TypeExpression)] {
        buried(
            at: place,
            stepping: { place, step in place.appending(step) },
            keepingStatement: { trail, statement in
                statement.binding?.declared.map { declared in [(trail, declared)] } ?? []
            },
            keepingExpression: { _, _ in [] }
        )
    }
}

extension Expression: Burying {}
extension Block: Burying {}
extension [Statement]: Burying {}

public extension Expression {
    func buried<Trail, Found>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        keepingStatement: (Trail, Statement) -> [(Trail, Found)],
        keepingExpression: (Trail, Expression) -> [(Trail, Found)]
    ) -> [(Trail, Found)] {
        // A closure names its own place: the literal and the body it carries
        // are found under one name, so a report says which closure without
        // having to say it twice.
        let here: Trail = if case .closure = self { stepping(trail, .slot(.closure)) } else { trail }

        func inner(_ expression: Expression, under slot: Place.Slot? = nil) -> [(Trail, Found)] {
            expression.buried(
                at: slot.map { slot in stepping(here, .slot(slot)) } ?? here,
                stepping: stepping,
                keepingStatement: keepingStatement,
                keepingExpression: keepingExpression
            )
        }

        // What a call is written with, walked in name order and each given its
        // own place. Order because a `Dictionary` walks in whatever order its
        // seed decided, and the stages downstream stop at the first refusal —
        // which one an author is shown would be a fact of the run rather than
        // of the text. Its own place because two of them reported from the
        // same one would say a thing is wrong and not say which.
        func arguments(_ children: [Name: Expression]) -> [(Trail, Found)] {
            named(children, under: stepping(here, .slot(.arguments)))
        }

        func named(_ children: [Name: Expression], under place: Trail) -> [(Trail, Found)] {
            children.sorted { mine, theirs in mine.key < theirs.key }
                .flatMap { name, child in
                    child.buried(
                        at: stepping(place, .key(name.spelling)),
                        stepping: stepping,
                        keepingStatement: keepingStatement,
                        keepingExpression: keepingExpression
                    )
                }
        }

        func block(_ block: Block, at trail: Trail) -> [(Trail, Found)] {
            block.buried(
                at: trail,
                stepping: stepping,
                keepingStatement: keepingStatement,
                keepingExpression: keepingExpression
            )
        }

        func statements(_ body: [Statement], at trail: Trail) -> [(Trail, Found)] {
            body.buried(
                at: trail,
                stepping: stepping,
                keepingStatement: keepingStatement,
                keepingExpression: keepingExpression
            )
        }

        let held: [(Trail, Found)] = switch self {
        case .literal, .reference:
            []

        case let .closure(procedure):
            procedure.block.map { held in block(held, at: here) } ?? []

        case let .cast(value, _, _):
            inner(value, under: .receiver)

        // A leave writes what it carries directly under its own construct,
        // which the statement holding it already stepped into.
        case let .leave(leave):
            leave.value.map { value in inner(value) } ?? []

        case let .array(array):
            array.enumerated().flatMap { position, element in
                element.buried(
                    at: stepping(here, .index(position)),
                    stepping: stepping,
                    keepingStatement: keepingStatement,
                    keepingExpression: keepingExpression
                )
            }

        case let .record(record):
            named(record, under: here)

        case let .invoke(callee, written):
            inner(callee, under: .callee) + arguments(written)

        case let .dispatch(dispatch):
            (dispatch.receiver.map { receiver in inner(receiver, under: .receiver) } ?? [])
                + arguments(dispatch.arguments)

        case let .block(held):
            block(held, at: here)

        case let .conditional(condition, then, otherwise):
            inner(condition, under: .condition(of: .branch))
                + statements(then, at: stepping(here, .slot(.then)))
                + (otherwise.map { held in statements(held, at: stepping(here, .slot(.otherwise))) } ?? [])

        case let .loop(condition, body, _):
            inner(condition, under: .condition(of: .loop))
                + block(body, at: here)

        case let .iteration(material, body, _):
            inner(material, under: .material)
                + statements(body, at: stepping(here, .slot(.body)))

        case let .attempt(attempted, rescue, _):
            block(attempted, at: here)
                + block(rescue, at: stepping(here, .slot(.rescue)))
        }

        return keepingExpression(here, self) + held
    }
}

public extension Block {
    func buried<Trail, Found>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        keepingStatement: (Trail, Statement) -> [(Trail, Found)],
        keepingExpression: (Trail, Expression) -> [(Trail, Found)]
    ) -> [(Trail, Found)] {
        body.buried(
            at: stepping(trail, .slot(.body)),
            stepping: stepping,
            keepingStatement: keepingStatement,
            keepingExpression: keepingExpression
        ) + (result.map { result in
            result.buried(
                at: stepping(trail, .slot(.result)),
                stepping: stepping,
                keepingStatement: keepingStatement,
                keepingExpression: keepingExpression
            )
        } ?? [])
    }
}

public extension [Statement] {
    // A statement is found under its own name — or, one run for its effect
    // alone, under its position, which is the only thing there is to call it —
    // and then under the construct it writes, the way a document nests it.
    func buried<Trail, Found>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        keepingStatement: (Trail, Statement) -> [(Trail, Found)],
        keepingExpression: (Trail, Expression) -> [(Trail, Found)]
    ) -> [(Trail, Found)] {
        enumerated().flatMap { position, statement in
            let here = stepping(trail, .statement(name: statement.name?.spelling, at: position))

            return keepingStatement(here, statement)
                + statement.expression.buried(
                    at: stepping(here, .construct(statement.expression.construct)),
                    stepping: stepping,
                    keepingStatement: keepingStatement,
                    keepingExpression: keepingExpression
                )
        }
    }
}
