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
        #expect(spin?.rendered == "procedures.entry.body.spin[0].loop.where")
        #expect(walk?.rendered == "procedures.entry.body.walk[0].each.in")
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
        #expect(sut?.rendered == "procedures.entry.body.sent[0].call.arguments.amount")
    }

    @Test("a statement is found by its name, and by its position when it has none")
    func aStatementIsFoundByWhicheverItHas() {
        // Given — a statement run for its effect alone fixes no name, and its
        // position is the only thing there is to call it.
        let named = place(refusing: Statement(id: "held", expression: reference("missing")))
        let bare = place(refusing: Statement(expression: reference("missing")))

        // Then
        #expect(named?.rendered == "procedures.entry.body.held[0].value")
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
        #expect(error?.place?.rendered == "procedures.entry.body.held[0].value")
        #expect(error?.message.contains("procedures.entry") == false)
        #expect(error?.description.hasPrefix("procedures.entry.body.held[0].value: ") == true)
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
        #expect(error?.place?.rendered == "procedures.entry.body.sent[0].call")
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
            error?.place?.rendered == "procedures.entry.body.sent[0].call.arguments.second"
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
        #expect(load?.place?.rendered == "procedures.entry.body.sent[0].call.arguments.amount")
        #expect(link?.place?.rendered == "procedures.entry.body.sent[0].call.arguments.amount")
    }

    @Test("every walk that reports a place steps through the same slots to reach one")
    func theWalksAgreeOnHowDeepASlotIs() throws {
        // Given — one call, buried under an attempt's rescue: a slot no walk
        // reaches without stepping through the keys between. Four walks report
        // places and each destructures the language for itself, so what one of
        // them forgets to step into is a place that reads like another one.
        //
        // Each of them is made to speak about this call in the way only it can:
        // a name nothing declares for the walk that checks the document against
        // itself, a word nothing declares for the walk that resolves names, a
        // claim the types already prove for the walk that reads them.
        let reached = "procedures.entry.body.guarded[0].attempt.rescue.body.sent[0].call"

        func module(sending selector: String, with argument: Warp.Expression) -> Module {
            Module(
                procedures: [
                    entryName: Procedure(body: [
                        Statement(
                            id: "guarded",
                            expression: .attempt(
                                Block(body: []),
                                rescue: Block(body: [
                                    Statement(
                                        id: "sent",
                                        expression: .dispatch(
                                            Dispatch(
                                                selector: selector,
                                                arguments: ["amount": argument]
                                            )
                                        )
                                    )
                                ]),
                                failure: "guarded"
                            )
                        )
                    ]),
                    "helper": Procedure(
                        signature: Signature(parameters: ["amount": Parameter(type: .int)]),
                        body: []
                    )
                ]
            )
        }

        // When
        let load = #expect(throws: ValidationError.self) {
            try Validator().validate(module(sending: "helper", with: reference("missing")))
        }

        let bound = #expect(throws: LinkError.self) {
            try Language().link(
                [module(sending: "nowhere", with: .literal(.int(1)))] + Module.standard,
                entry: entryName
            )
        }

        let typed = #expect(throws: LinkError.self) {
            try Language().link(
                [module(
                    sending: "helper",
                    with: .cast(.literal(.int(1)), as: .int, optional: false)
                )] + Module.standard,
                entry: entryName
            )
        }

        // Then — each says something different about the call, from one place
        #expect(load?.place?.rendered.hasPrefix(reached) == true)
        #expect(bound?.place?.rendered.hasPrefix(reached) == true)
        #expect(typed?.place?.rendered.hasPrefix(reached) == true)

        // And the walk that only gathers puts it in the same place
        let gathered = try #require(
            module(sending: "helper", with: .literal(.int(1)))
                .procedures[entryName]?.block?
                .buried(at: .procedure(entryName, in: .shared))
                .first { _, expression in
                    guard case .dispatch = expression else { return false }

                    return true
                }
        )

        #expect(gathered.0.rendered == reached)
    }

    @Test("a named module does not put its name in the place")
    func aModuleNameIsNotADocumentKey() {
        // Given — the same refusal from a module that has a name. A link calls
        // this declaration `wallet.entry`, and no document writes that: the
        // name is a field beside `procedures`, and what `procedures` holds is
        // the declared key alone.
        let sut = Module(
            name: "wallet",
            procedures: [
                entryName: Procedure(body: [
                    Statement(id: "sent", expression: .dispatch(Dispatch(selector: "nowhere")))
                ])
            ]
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then — the name says which document, and never which key
        #expect(error?.place?.document == .named("wallet"))
        #expect(error?.place?.steps.contains(.key("wallet.entry")) == false)
        #expect(error?.place?.rendered == "wallet/procedures.entry.body.sent[0].call")
    }

    @Test("a program with no document under it says so, rather than saying no name")
    func anAssembledProgramNamesNoDocument() {
        // Given — a procedure handed in on its own, which is what a caller
        // assembling a program in memory holds. There is no document, which is
        // a different fact from a document that wrote no name: reading them as
        // one would match this against any text an author never named, and
        // answer with that text's own first line.
        let sut = Procedure(body: [Statement(id: "held", expression: reference("missing"))])

        // When
        let assembled = #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }

        let read = #expect(throws: ValidationError.self) {
            try Validator().validate(module(refusing: Statement(expression: reference("missing"))))
        }

        // Then
        #expect(assembled?.place?.document == .assembled)
        #expect(read?.place?.document == .shared)
    }

    @Test("a shape a named module declares is placed by the key it declared it under")
    func aTypeInANamedModuleIsPlacedByItsDeclaredKey() {
        // Given — a named module, whose type keys the link rewrites into the
        // names it calls them by. A place spelled from one of those carries the
        // module's name twice and leads nowhere: `types.wallet.Coin` is not
        // what any document writes.
        let sut = Module(
            name: "wallet",
            types: ["Coin": .record(["amount": .named("Missing")])],
            procedures: [entryName: Procedure(body: [])]
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then
        #expect(error?.place?.rendered == "wallet/types.Coin.amount")
    }

    @Test("a membership a named module declares is placed the same way")
    func aConstraintInANamedModuleIsPlacedByItsDeclaredKey() {
        // Given — the other space the qualifying pass rewrites keys in. A
        // membership admitting nothing is refused from the table alone, which
        // is the walk that has only the link's names to go on.
        let sut = Module(
            name: "wallet",
            constraints: ["Spendable": []],
            procedures: [entryName: Procedure(body: [])]
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then
        #expect(error?.place?.rendered == "wallet/constraints.Spendable")
    }

    @Test("a statement's construct is the language's word, and says so")
    func aConstructIsNotClaimedAsTheDocumentsOwn() throws {
        // Given — one shape, two texts: `{ call: … }` and `{ value: { call:
        // … } }` are both a dispatch by the time anything here sees one, so
        // the word for the construct is this implementation's rather than
        // something a reader may go looking for in a file.
        let sut = try #require(
            place(
                refusing: Statement(
                    id: "sent",
                    expression: .dispatch(
                        Dispatch(selector: "send", arguments: ["amount": reference("missing")])
                    )
                )
            )
        )

        // Then — the word is spelled for the person reading the line
        #expect(sut.rendered.contains(".sent[0].call."))

        // And carried as the language's, beside the keys that are the text's
        #expect(sut.steps.contains(.landmark("call")))
        #expect(sut.steps.contains(.key("call")) == false)
        #expect(sut.steps.contains(.key("arguments")))
    }

    @Test("what a return carries is checked, and placed where the return is")
    func aReturnsValueIsWalked() {
        // Given — the door a caller assembling a program itself passes. What
        // `return` carries is an operand like any other: a name it reads has
        // to be visible where it was written.
        let sut = module(
            refusing: Statement(
                expression: .leave(Leave(reach: .procedure, value: reference("missing")))
            )
        )

        // When
        let error = #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body[0].return")
    }

    @Test("both stages point at the statement that leaves, not at what follows it")
    func theLeaveRuleIsPlacedOnTheLeavingStatement() {
        // Given — the one rule both stages hold: the load catches the leaves
        // the text shows, the link catches the word that declares `never`.
        // What an author has to change is the statement that ends the body, so
        // that is where each of them says it is.
        let shown = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(expression: .leave(Leave(reach: .procedure))),
                    Statement(id: "after", expression: .literal(.int(1)))
                ])
            ]
        )

        let declared = Module(
            procedures: [
                entryName: Procedure(body: [
                    Statement(
                        expression: .dispatch(
                            Dispatch(selector: "stop", arguments: ["message": .literal(.string("x"))])
                        )
                    ),
                    Statement(id: "after", expression: .literal(.int(1)))
                ]),
                "stop": Procedure(
                    signature: Signature(
                        parameters: ["message": Parameter(type: .string)],
                        returns: .never
                    ),
                    body: [Statement(expression: .leave(Leave(reach: .procedure)))]
                )
            ]
        )

        // When
        let load = #expect(throws: ValidationError.self) { try Validator().validate(shown) }
        let link = #expect(throws: LinkError.self) {
            try Language().link([declared] + Module.standard, entry: entryName)
        }

        // Then
        #expect(load?.place?.rendered == "procedures.entry.body[0].return")
        #expect(link?.place?.rendered == "procedures.entry.body[0].call")
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
