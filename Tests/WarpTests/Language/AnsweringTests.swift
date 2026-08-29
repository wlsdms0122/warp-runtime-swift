//
//  AnsweringTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// What a declaration answers when nobody wrote it down.
//
// An unwritten `returns` used to read as `any`, which cost a call site nothing
// while `any` was accepted everywhere. Making `any` opaque turned it into a
// bill: a dot on what such a call answers was refused, and the author was
// asked to write down a shape the body already states.
//
// So the body is read, in the call graph's order. What the author wrote stays
// what the image carries — this is the link's own reading, not a promise
// anybody made — and where the reading would have to come from itself, it says
// `any` rather than guessing.
@Suite("An answer nobody wrote is read off the body")
struct AnsweringTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a dot stands on what an undeclared call answers")
    func aDotStandsOnAnUnwrittenAnswer() async throws {
        // Given — `counts` declares no answer and its body answers a record.
        // The dot after the call is judged against that record, which is the
        // whole of what this buys: the shape the body states does not have to
        // be stated twice.
        let sut = Module(
            procedures: [
                "counts": Procedure(
                    body: [],
                    result: .record(["total": .literal(.int(7))])
                ),
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "counts"))
                        )
                    ],
                    result: .reference([.key("said"), .key("total")])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(7))
    }

    @Test("an answer read off one body reaches the next")
    func ananswerTravelsTheCallGraph() async throws {
        // Given — three declarations, none of which says what it answers. The
        // order is the call graph's, so each is read after the one its answer
        // comes from.
        let sut = Module(
            procedures: [
                "innermost": Procedure(body: [], result: .record(["total": .literal(.int(3))])),
                "middle": Procedure(
                    body: [],
                    result: .dispatch(Dispatch(selector: "innermost"))
                ),
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "middle"))
                        )
                    ],
                    result: .reference([.key("said"), .key("total")])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(3))
    }

    @Test("every way out of a body is one of its answers")
    func aReturnIsAnAnswerToo() throws {
        // Given — a body whose result answers a record, with and without an
        // early `return` carrying a string. A body hands its caller either
        // way out, so the second answers what holds both, and a dot on that is
        // refused the way a dot on `any` is. Reading the result alone would
        // have called both a record and let both dots stand.
        func module(leaving early: Bool) -> Module {
            Module(
                procedures: [
                    "counts": Procedure(
                        signature: Signature(parameters: ["flag": Parameter(type: .bool)]),
                        body: early
                            ? [
                                Statement(
                                    expression: .conditional(
                                        equals(
                                            .reference([.key("flag")]),
                                            .literal(.bool(true))
                                        ),
                                        then: [
                                            Statement(
                                                expression: .leave(Leave(
                                                    reach: .procedure,
                                                    value: .literal(.string("none"))
                                                ))
                                            )
                                        ],
                                        else: nil
                                    )
                                )
                            ]
                            : [],
                        result: .record(["total": .literal(.int(7))])
                    ),
                    entryName: Procedure(
                        body: [
                            Statement(
                                id: "said",
                                expression: .dispatch(Dispatch(
                                    selector: "counts",
                                    arguments: ["flag": .literal(.bool(true))]
                                ))
                            )
                        ],
                        result: .reference([.key("said"), .key("total")])
                    )
                ]
            )
        }

        // When / Then — one way out, and the dot is judged against it
        _ = try language.link([module(leaving: false)] + Module.standard, entry: entryName)

        // Two, and what holds both says nothing about a field
        #expect {
            try language.link([module(leaving: true)] + Module.standard, entry: entryName)
        } throws: { error in
            error is LinkError && "\(error)".contains("which declares nothing")
        }
    }

    @Test("an answer that would come from itself says nothing")
    func acircleAnswersAny() throws {
        // Given — two declarations whose answers are each other's. Reading
        // either needs the other, so neither is read: an answer worked out
        // from itself is not one the text states, and a guess there would be
        // a refusal an author cannot act on.
        let sut = Module(
            procedures: [
                "ping": Procedure(body: [], result: .dispatch(Dispatch(selector: "pong"))),
                "pong": Procedure(body: [], result: .dispatch(Dispatch(selector: "ping"))),
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "ping"))
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then — nothing is claimed, so nothing is refused
        _ = try language.link([sut] + Module.standard, entry: entryName)

        // And a dot on it refuses, because `any` is what saying nothing looks
        // like at a call site — where the same shape with the circle broken
        // reads the record `pong` answers.
        func reading(circling: Bool) -> Module {
            Module(
                procedures: [
                    "ping": Procedure(body: [], result: .dispatch(Dispatch(selector: "pong"))),
                    "pong": Procedure(
                        body: [],
                        result: circling
                            ? .dispatch(Dispatch(selector: "ping"))
                            : .record(["total": .literal(.int(1))])
                    ),
                    entryName: Procedure(
                        body: [
                            Statement(
                                id: "said",
                                expression: .dispatch(Dispatch(selector: "ping"))
                            )
                        ],
                        result: .reference([.key("said"), .key("total")])
                    )
                ]
            )
        }

        #expect(throws: LinkError.self) {
            try language.link([reading(circling: true)] + Module.standard, entry: entryName)
        }

        _ = try language.link([reading(circling: false)] + Module.standard, entry: entryName)
    }

    @Test("an answer naming a type parameter is filled at the call, or fills with nothing")
    func aParameterAnswerIsFilledWhereTheCallCanFillIt() throws {
        // Given — `peek` declares no answer, and what its body hands back
        // names a type parameter. That goes through the same filling a
        // declared `returns: some T` does, so which of the two shapes it is
        // decides itself: the parameter is a slot the signature declares and
        // the call fills it, and what a walk *through* a parameter reached is
        // named for a path only that body can read, which nothing fills.
        func module(reading path: [PathSegment], answering answer: [PathSegment]) -> Module {
            Module(
                procedures: [
                    "peek": Procedure(
                        signature: Signature(
                            parameters: ["of": Parameter(type: .variable(name: "T"))]
                        ),
                        body: [],
                        result: .reference(answer)
                    ),
                    entryName: Procedure(
                        body: [
                            Statement(
                                id: "said",
                                expression: .dispatch(Dispatch(
                                    selector: "peek",
                                    arguments: [
                                        "of": .record(["inner": .literal(.int(1))])
                                    ]
                                ))
                            )
                        ],
                        result: .reference(path)
                    )
                ]
            )
        }

        // When / Then — the parameter itself: filled with what the call put
        // there, so the caller reads that record and is held to it
        _ = try language.link(
            [module(reading: [.key("said"), .key("inner")], answering: [.key("of")])]
                + Module.standard,
            entry: entryName
        )

        #expect {
            try language.link(
                [module(reading: [.key("said"), .key("missing")], answering: [.key("of")])]
                    + Module.standard,
                entry: entryName
            )
        } throws: { error in
            error is LinkError && "\(error)".contains("does not declare")
        }

        // And a field of it: a name only `peek` could read, which no call
        // fills — so the caller reads `any` and the dot is refused
        #expect {
            try language.link(
                [module(
                    reading: [.key("said"), .key("inner")],
                    answering: [.key("of"), .key("inner")]
                )] + Module.standard,
                entry: entryName
            )
        } throws: { error in
            error is LinkError && "\(error)".contains("which declares nothing")
        }
    }

    @Test("what the author wrote is what the image carries")
    func theDeclarationIsNotRewritten() throws {
        // Given — the reading is the link's own note to itself. A declaration
        // is a promise, and one read off a body is not a promise anybody made:
        // writing it back would make the boundary check a shape nobody wrote,
        // and would put it in a document the writer hands back.
        let sut = Module(
            procedures: [
                entryName: Procedure(body: [], result: .literal(.int(7)))
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image.entry.signature.returns == nil)
    }

    // MARK: - Public
    // MARK: - Private
}
