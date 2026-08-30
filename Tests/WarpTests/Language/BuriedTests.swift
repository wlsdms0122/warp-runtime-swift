//
//  BuriedTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// One walk over everything an expression holds.
//
// Three stages want all of it and differ only in what they keep — the closure
// literals a body buries, the shapes its casts name, the selectors it sends —
// and each used to walk the language itself. A case added to `Expression`
// reached whichever copies somebody remembered, and a case *handled* but not
// descended into reached none of them while still compiling.
//
// The switch has no default, so a new case cannot be forgotten. What it cannot
// say is that the case goes *through*: an arm answering `[]` compiles. That is
// what this asks — a marker in every position a child can sit in, and the walk
// has to come back with all of them.
@Suite("One walk finds everything an expression holds")
struct BuriedTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every position a child sits in is walked through")
    func everyChildPositionIsReached() {
        // Given — one marker per position, so a missing one names itself
        func marker(_ name: String) -> Warp.Expression { .literal(.string(name)) }

        let sut = Warp.Expression.array([
            .cast(marker("cast operand"), as: .int, optional: false),
            .leave(Leave(reach: .procedure, value: marker("leave value"))),
            .record(["field": marker("record field")]),
            .closure(Procedure(
                body: [Statement(id: "inside", expression: marker("closure body"))],
                result: marker("closure result")
            )),
            .invoke(marker("invoke callee"), arguments: ["to": marker("invoke argument")]),
            .dispatch(Dispatch(
                receiver: marker("dispatch receiver"),
                selector: "word",
                arguments: ["with": marker("dispatch argument")]
            )),
            .block(Block(
                body: [Statement(id: "held", expression: marker("block body"))],
                result: marker("block result")
            )),
            .conditional(
                marker("branch condition"),
                then: [Statement(expression: marker("branch then"))],
                else: [Statement(expression: marker("branch else"))]
            ),
            .loop(
                while: marker("loop condition"),
                body: Block(body: [Statement(expression: marker("loop body"))]),
                round: "round"
            ),
            .iteration(
                over: marker("walk material"),
                body: [Statement(expression: marker("walk body"))],
                element: "each"
            ),
            .attempt(
                Block(body: [Statement(expression: marker("attempt body"))]),
                rescue: Block(body: [Statement(expression: marker("attempt rescue"))]),
                failure: "failure"
            )
        ])

        // When
        let found = Set(sut.buried.compactMap { expression -> String? in
            guard case let .literal(.string(name)) = expression else { return nil }

            return name
        })

        // Then — every marker, by name
        #expect(found == [
            "cast operand", "leave value", "record field",
            "closure body", "closure result",
            "invoke callee", "invoke argument",
            "dispatch receiver", "dispatch argument",
            "block body", "block result",
            "branch condition", "branch then", "branch else",
            "loop condition", "loop body",
            "walk material", "walk body",
            "attempt body", "attempt rescue"
        ])
    }

    @Test("a place names where a thing was found, and a closure names its own")
    func aPlaceNamesWhereAThingWasFound() {
        // Given — the location a report quotes. A closure literal and the body
        // it carries answer under one name, so a refusal says which closure
        // without having to say it twice.
        let sut = Block(
            body: [Statement(
                id: "held",
                expression: .closure(Procedure(
                    body: [],
                    result: .cast(.literal(.int(1)), as: .int, optional: false)
                ))
            )],
            result: .attempt(
                Block(body: []),
                rescue: Block(
                    body: [Statement(expression: .cast(.literal(.int(2)), as: .string, optional: false))]
                ),
                failure: "failure"
            )
        )

        // When
        let casts = sut.buried(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .cast = expression else { return nil }

            return place.rendered
        }

        // Then
        #expect(casts == ["entry.body.held[0].value.closure.result", "entry.result.rescue.body[0].value"])

        // And the closure literal is found at the place its body is
        let closures = sut.buried(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .closure = expression else { return nil }

            return place.rendered
        }

        #expect(closures == ["entry.body.held[0].value.closure"])
    }

    @Test("named children are walked in name order, each under its own place")
    func siblingsAreToldApart() {
        // Given — three casts sitting side by side under names. The stages
        // that read this walk report the first thing they refuse, so which
        // sibling an author is shown has to be a fact of the text; and the
        // place they report has to say which one it was.
        //
        // Walked in whatever order a `Dictionary` handed them and reported
        // from one shared place, both were lost: the first refusal moved from
        // run to run, and the place it named was the record, not the field.
        let sut = Warp.Expression.record([
            "beta": .cast(.literal(.int(2)), as: .string, optional: false),
            "alpha": .cast(.literal(.int(1)), as: .string, optional: false),
            "gamma": .cast(.literal(.int(3)), as: .string, optional: false)
        ])

        // When
        let casts = sut.buried(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .cast = expression else { return nil }

            return place.rendered
        }

        // Then
        #expect(casts == ["entry.alpha", "entry.beta", "entry.gamma"])

        // And the same holds for what a call is written with.
        let sent = Warp.Expression.dispatch(Dispatch(
            selector: "send",
            arguments: [
                "second": .cast(.literal(.int(2)), as: .string, optional: false),
                "first": .cast(.literal(.int(1)), as: .string, optional: false)
            ]
        ))

        #expect(
            sent.buried(at: .given("entry")).compactMap { place, expression -> String? in
                guard case .cast = expression else { return nil }

                return place.rendered
            } == ["entry.arguments.first", "entry.arguments.second"]
        )
    }

    // MARK: - Public
    // MARK: - Private
}
