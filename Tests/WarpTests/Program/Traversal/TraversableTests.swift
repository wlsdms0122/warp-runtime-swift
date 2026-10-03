//
//  TraversableTests.swift
//  WarpTests
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Testing
@testable import Warp

// One walk over everything an expression holds.
//
// The switch has no default, so a new case cannot be forgotten, but an arm
// answering `[]` compiles. So a marker stands in every position a child can
// sit in, and the walk has to come back with all of them.
@Suite("One walk finds everything an expression holds")
struct TraversableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every position a child sits in is walked through")
    func everyChildPositionIsReached() {
        // Given. One marker per position, so a missing one names itself
        func marker(_ name: String) -> Warp.Expression { .literal(.string(name)) }

        let sut = Warp.Expression.array([
            .cast(marker("cast operand"), as: .int, optional: false),
            .leave(Leave(reach: .procedure, value: marker("leave value"))),
            .record(["field": marker("record field")]),
            .closure(Procedure(
                body: [Statement(binding: .constant("inside"), expression: marker("closure body"))],
                result: marker("closure result")
            )),
            .apply(marker("apply callee"), arguments: [marker("apply argument")]),
            .call(Call(selector: "procedure", arguments: [marker("call first argument"), marker("call second argument")])),
            .block(Block(
                body: [Statement(binding: .constant("held"), expression: marker("block body"))],
                result: marker("block result")
            )),
            .conditional(
                marker("conditional condition"),
                then: [Statement(expression: marker("conditional then"))],
                else: [Statement(expression: marker("conditional else"))]
            ),
            .loop(
                while: marker("loop condition"),
                body: Block(body: [Statement(expression: marker("loop body"))])
            ),
            .attempt(
                Block(body: [Statement(expression: marker("attempt body"))]),
                rescue: Block(body: [Statement(expression: marker("attempt rescue"))])
            )
        ])

        // When
        let found = Set(sut.subexpressions.compactMap { expression -> String? in
            guard case let .literal(.string(name)) = expression else { return nil }

            return name
        })

        // Then. Every marker, by name
        #expect(found == [
            "cast operand", "leave value", "record field",
            "closure body", "closure result",
            "apply callee", "apply argument",
            "call first argument", "call second argument",
            "block body", "block result",
            "conditional condition", "conditional then", "conditional else",
            "loop condition", "loop body",
            "attempt body", "attempt rescue"
        ])
    }

    @Test("every place the type check records a judgement at is one the walk reaches, of the kind standing there")
    func everyCallOfAValueStandsWhereTheWalkReaches() async throws {
        // Given. A call of a value handing a variable in place, written in
        // every position a statement can stand in, and in closures held by
        // every operand that can hold one
        func name(_ spelling: String) -> Warp.Expression { .reference([.key(Name(stringLiteral: spelling))]) }

        let call = Statement(expression: .apply(name("bump"), arguments: [name("count")]))

        func closure() -> Warp.Expression {
            .closure(Procedure(body: [call], result: .literal(.null)))
        }

        let sut = Block(
            body: [
                Statement(binding: .variable("count"), expression: .literal(.int(0))),
                Statement(binding: .variable("going"), expression: .literal(.bool(true))),
                Statement(
                    binding: .constant("bump"),
                    expression: .closure(
                        Procedure(
                            signature: Signature(parameters: [Parameter(name: "held", type: .inout(.int))]),
                            body: [],
                            result: .literal(.null)
                        )
                    )
                ),
                call,
                Statement(expression: .block(Block(body: [call], result: closure()))),
                Statement(expression: .conditional(name("going"), then: [call], else: [call])),
                Statement(
                    expression: .loop(
                        while: name("going"),
                        body: Block(body: [call, Statement(expression: .leave(Leave(reach: .construct)))], result: closure())
                    )
                ),
                Statement(expression: .attempt(Block(body: [call]), rescue: Block(body: [call]))),
                Statement(binding: .constant("listed"), expression: .array([closure()])),
                Statement(binding: .constant("fielded"), expression: .record(["held": closure()])),
                Statement(binding: .constant("cast"), expression: .cast(closure(), as: .procedure(nil), optional: false)),
                Statement(expression: .apply(name("bump"), arguments: [name("count")]))
            ],
            result: closure()
        )
        let place = Place.procedure("entry", in: .assembled)
        let context = TypingContext(
            types: TypeTable(),
            linked: [],
            rows: [:],
            own: [:],
            concealed: [],
            answers: [:],
            contractProcedures: [:],
            variables: []
        )

        // When
        let (_, _, judgements, _) = try await TypeChecker().resolvedSites(
            in: sut,
            at: place,
            in: [:],
            answering: nil,
            with: context,
            folding: nil,
            writing: Fulfillment()
        )

        // Then. The table holds one entry for each call of a value and each
        // closure literal the walk reaches, under the place the walk reaches
        // it at, and of the kind that stands there
        let found = sut.subexpressions(at: place)
        let calls = found.filter { _, expression in
            if case .apply = expression { return true }

            return false
        }.map(\.0)
        let closures = found.filter { _, expression in
            if case .closure = expression { return true }

            return false
        }.map(\.0)
        let judgedCalls = judgements.judgements.filter { _, judgement in
            if case .apply = judgement { return true }

            return false
        }.keys
        let judgedClosures = judgements.judgements.filter { _, judgement in
            if case .closure = judgement { return true }

            return false
        }.keys

        #expect(calls.count == 14)
        #expect(closures.count == 7)
        #expect(Set(judgedCalls) == Set(calls))
        #expect(Set(judgedClosures) == Set(closures))
    }

    @Test("a place names where a thing was found, and a closure names its own")
    func aPlaceNamesWhereAThingWasFound() {
        // Given. The location a report quotes. A closure literal and the body
        // it carries answer under one name, so a refusal says which closure
        // without having to say it twice.
        let sut = Block(
            body: [Statement(binding: .constant("held"), expression: .closure(Procedure(
                    body: [],
                    result: .cast(.literal(.int(1)), as: .int, optional: false)
                ))
            )],
            result: .attempt(
                Block(body: []),
                rescue: Block(
                    body: [Statement(expression: .cast(.literal(.int(2)), as: .string, optional: false))]
                )
            )
        )

        // When
        let casts = sut.subexpressions(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .cast = expression else { return nil }

            return place.rendered
        }

        // Then
        #expect(casts == ["entry.body.held[0].closure.closure.result", "entry.result.rescue.body[0].cast"])

        // And the closure literal is found at the place its body is
        let closures = sut.subexpressions(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .closure = expression else { return nil }

            return place.rendered
        }

        #expect(closures == ["entry.body.held[0].closure.closure"])
    }

    @Test("named children are walked in name order, each under its own place")
    func siblingsAreToldApart() {
        // Given. Three casts sitting side by side under names. The stages that
        // read this walk report the first thing they refuse, so which sibling
        // an author is shown has to be a fact of the text; and the place they
        // report has to say which one it was.
        let sut = Warp.Expression.record([
            "beta": .cast(.literal(.int(2)), as: .string, optional: false),
            "alpha": .cast(.literal(.int(1)), as: .string, optional: false),
            "gamma": .cast(.literal(.int(3)), as: .string, optional: false)
        ])

        // When
        let casts = sut.subexpressions(at: .given("entry")).compactMap { place, expression -> String? in
            guard case .cast = expression else { return nil }

            return place.rendered
        }

        // Then
        #expect(casts == ["entry.fields.alpha", "entry.fields.beta", "entry.fields.gamma"])

        // And what a call is written with is walked in position order, each
        // argument under its own place.
        let sent = Warp.Expression.call(Call(
            selector: "send",
            arguments: [
                .cast(.literal(.int(1)), as: .string, optional: false),
                .cast(.literal(.int(2)), as: .string, optional: false)
            ]
        ))

        #expect(
            sent.subexpressions(at: .given("entry")).compactMap { place, expression -> String? in
                guard case .cast = expression else { return nil }

                return place.rendered
            } == ["entry.arguments[0]", "entry.arguments[1]"]
        )
    }

    // MARK: - Public
    // MARK: - Private
}
