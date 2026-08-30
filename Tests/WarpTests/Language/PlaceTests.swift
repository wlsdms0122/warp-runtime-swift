//
//  PlaceTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// Where a refusal says the words are.
//
// An author reading one has the document in front of them, so what these ask of
// every place is one thing: that following it word by word lands on something
// the author typed. A place spelled out of the model's own names — the enum
// case, the Swift label — reads like a path and leads nowhere.
@Suite
struct PlaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a place is spelled from the keys the document writes")
    func aPlaceIsSpelledFromDocumentKeys() {
        // Given — the two slots whose model name and document key differ. A
        // loop's condition is `while` to this implementation and `where` to
        // every document; a walk's collection is `over` here and `in` there.
        let spin = place(
            refusing: Statement(
                id: "spin",
                expression: .loop(
                    while: .block(Block(body: [], result: .literal(.bool(true)))),
                    body: Block(body: []),
                    round: "spin"
                )
            )
        )

        let walk = place(
            refusing: Statement(
                id: "walk",
                expression: .iteration(over: reference("missing"), body: [], element: "walk")
            )
        )

        // Then
        #expect(spin?.rendered == "procedures.entry.body.spin.loop.where")
        #expect(walk?.rendered == "procedures.entry.body.walk.each.in")
    }

    @Test("what a call is written with is named under the key holding it")
    func anArgumentIsNamedUnderItsKey() {
        // Given — an argument reported from the statement's own place says a
        // thing is wrong and does not say which of the several written there.
        let sut = place(
            refusing: Statement(
                id: "sent",
                expression: .dispatch(
                    Dispatch(selector: "send", arguments: ["amount": reference("missing")])
                )
            )
        )

        // Then
        #expect(sut?.rendered == "procedures.entry.body.sent.call.arguments.amount")
    }

    @Test("a statement is found by its name, and by its position when it has none")
    func aStatementIsFoundByWhicheverItHas() {
        // Given — a statement run for its effect alone fixes no name, and its
        // position is the only thing there is to call it.
        let named = place(refusing: Statement(id: "held", expression: reference("missing")))
        let bare = place(refusing: Statement(expression: reference("missing")))

        // Then
        #expect(named?.rendered == "procedures.entry.body.held.value")
        #expect(bare?.rendered == "procedures.entry.body[0].value")

        // And the name is not all that is kept: a reader mapping a place back
        // to the text it was written in needs the position, which a name would
        // have spent.
        #expect(named?.steps.contains(.statement(name: "held", at: 0)) == true)
    }

    @Test("a signature's slots are named under the key a procedure declares them with")
    func parametersAreNamedAsTheDocumentNamesThem() {
        // Given — a name a document may not write, so the refusal is the
        // declaration's own rather than anything a body did with it
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["cafe\u{301}": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When
        let error = #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.parameters.cafe\u{301}")
    }

    @Test("the place is carried as data, and the sentence is only the reason")
    func aPlaceIsNotProse() {
        // Given — a place written into the message is a place nothing can
        // read back. A front end holding the file this was authored in has to
        // walk the steps to point at the line, and a sentence has no steps.
        let sut = module(refusing: Statement(id: "held", expression: reference("missing")))

        // When
        let error = #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.held.value")
        #expect(error?.message.contains("procedures.entry") == false)
        #expect(error?.description.hasPrefix("procedures.entry.body.held.value: ") == true)
    }

    @Test("what the link refuses is placed the way what the load refuses is")
    func bothStagesSpellOnePlace() {
        // Given — one document, refused at the link: the two stages walk the
        // same text and an author reading both should not have to learn two
        // spellings of where they are.
        let sut = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(id: "sent", expression: .dispatch(Dispatch(selector: "nowhere")))
                ])
            ]
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: entryName)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.sent.call")
    }

    @Test("the link narrows to the argument it refused, not to the call holding it")
    func aLinkRefusalNarrowsToTheArgument() {
        // Given — a call written with several arguments, one of which holds
        // what the declaration does not take. Reported from the call, an
        // author is told a thing is wrong and not which of the three it is.
        let sut = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(
                        id: "sent",
                        expression: .dispatch(
                            Dispatch(selector: "helper", arguments: [
                                "first": .literal(.int(1)),
                                "second": .literal(.string("two")),
                                "third": .literal(.int(3))
                            ])
                        )
                    )
                ]),
                "helper": Procedure(
                    signature: Signature(parameters: [
                        "first": Parameter(type: .int),
                        "second": Parameter(type: .int),
                        "third": Parameter(type: .int)
                    ]),
                    body: []
                )
            ]
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: entryName)
        }

        // Then
        #expect(
            error?.place?.rendered == "procedures.entry.body.sent.call.arguments.second"
        )
    }

    @Test("one place, whichever stage walked the text")
    func theTwoStagesSpellOneSlotOneWay() {
        // Given — the same slot of the same statement, reached once by the
        // walk that checks a document against itself and once by the walk that
        // resolves its names. Two spellings of one place is two documents as
        // far as an author following the words is concerned.
        let refused = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(
                        id: "sent",
                        expression: .dispatch(
                            Dispatch(selector: "helper", arguments: ["amount": reference("missing")])
                        )
                    )
                ])
            ]
        )

        let linked = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(
                        id: "sent",
                        expression: .dispatch(
                            Dispatch(selector: "helper", arguments: ["amount": .literal(.string("x"))])
                        )
                    )
                ]),
                "helper": Procedure(
                    signature: Signature(parameters: ["amount": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When
        let load = #expect(throws: ValidationError.self) { try Validator().validate(refused) }
        let link = #expect(throws: LinkError.self) {
            try Language().link([linked] + Module.standard, entry: entryName)
        }

        // Then
        #expect(load?.place?.rendered == "procedures.entry.body.sent.call.arguments.amount")
        #expect(link?.place?.rendered == "procedures.entry.body.sent.call.arguments.amount")
    }

    // MARK: - Public
    // MARK: - Private
    private func module(refusing statement: Statement) -> Module {
        Module(procedures: [entryName: Procedure(body: [statement])])
    }

    private func place(refusing statement: Statement) -> Place? {
        let error = #expect(throws: ValidationError.self) {
            try Validator().validate(module(refusing: statement))
        }

        return error?.place
    }
}
