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
    func parametersAreNamedAsTheDocumentNamesThem() throws {
        // Given — a name a document may not write, so the refusal is the
        // declaration's own rather than anything a body did with it
        // When
        let error = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(
                        signature: Signature(parameters: ["cafe\u{301}": Parameter(type: .int)]),
                        body: []
                    )
                ]
            )
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.parameters.cafe\u{301}")
    }

    @Test("the place is carried as data, and the sentence is only the reason")
    func aPlaceIsNotProse() throws {
        // Given — a place written into the message is a place nothing can
        // read back. A front end holding the file this was authored in has to
        // walk the steps to point at the line, and a sentence has no steps.
        // When
        let error = #expect(throws: ValidationError.self) {
            try module(refusing: Statement(id: "held", expression: reference("missing")))
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.held[0].value")
        #expect(error?.message.contains("procedures.entry") == false)
        #expect(error?.description.hasPrefix("procedures.entry.body.held[0].value: ") == true)
    }

    @Test("what the link refuses is placed the way what the load refuses is")
    func bothStagesSpellOnePlace() throws {
        // Given — one document, refused at the link: the two stages walk the
        // same text and an author reading both should not have to learn two
        // spellings of where they are.
        let sut = try Module(
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
    func aLinkRefusalNarrowsToTheArgument() throws {
        // Given — a call written with several arguments, one of which holds
        // what the declaration does not take. Reported from the call, an
        // author is told a thing is wrong and not which of the three it is.
        let sut = try Module(
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
    func theTwoStagesSpellOneSlotOneWay() throws {
        // Given — the same slot of the same statement, reached once by the
        // walk that checks a document against itself and once by the walk that
        // resolves its names. Two spellings of one place is two documents as
        // far as an author following the words is concerned.
        let linked = try Module(
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
        let load = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(body: [
                        Statement(
                            id: "sent",
                            expression: .dispatch(
                                Dispatch(
                                    selector: "helper",
                                    arguments: ["amount": reference("missing")]
                                )
                            )
                        )
                    ])
                ]
            )
        }

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

        func module(sending selector: String, with argument: Warp.Expression) throws -> Module {
            try Module(
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
        #expect(load?.place?.rendered?.hasPrefix(reached) == true)
        #expect(bound?.place?.rendered?.hasPrefix(reached) == true)
        #expect(typed?.place?.rendered?.hasPrefix(reached) == true)

        // And the walk that only gathers puts it in the same place
        let gathered = try #require(
            module(sending: "helper", with: .literal(.int(1)))
                .procedures[entryName]?.block?
                .buried(at: .procedure(entryName, in: .assembled))
                .first { _, expression in
                    guard case .dispatch = expression else { return false }

                    return true
                }
        )

        #expect(gathered.0.rendered == reached)
    }

    @Test("a named module does not put its name in the place")
    func aModuleNameIsNotADocumentKey() throws {
        // Given — the same refusal from a module that has a name. A link calls
        // this declaration `wallet.entry`, and no document writes that: the
        // name is a field beside `procedures`, and what `procedures` holds is
        // the declared key alone.
        let sut = try Module(
            name: "wallet",
            procedures: [
                entryName: Procedure(body: [
                    Statement(id: "sent", expression: .dispatch(Dispatch(selector: "nowhere")))
                ])
            ],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then — the name rides beside the steps and is never one of them
        #expect(error?.place?.document == Place.Document(identity: reading, namespace: "wallet"))
        #expect(error?.place?.steps.contains(.key("wallet.entry")) == false)
        #expect(error?.place?.rendered == "wallet@d0cf00/procedures.entry.body.sent[0].call")
    }

    @Test("a program nobody wrote down says so, rather than saying no name")
    func anAssembledProgramNamesNoDocument() {
        // Given — the same program twice: once handed in as a caller assembling
        // one in memory holds it, and once read out of a document. There is no
        // text under the first, which is a different fact from a text that
        // wrote no name — reading them as one would match a program nobody
        // wrote against a file somebody did, and answer with that file's line.
        let statement = Statement(expression: reference("missing"))

        // When
        let assembled = #expect(throws: ValidationError.self) {
            try Validator().validate(module(refusing: statement))
        }

        let read = #expect(throws: ValidationError.self) {
            try Validator().validate(module(refusing: statement, in: reading))
        }

        // Then
        #expect(assembled?.place?.document == .assembled)
        #expect(read?.place?.document == Place.Document(identity: reading, namespace: nil))
    }

    @Test("two halves of a split module do not read as one, to a person either")
    func oneNameIsTwoDocumentsInTheLineToo() {
        // Given — one module written across two files, which is a thing a link
        // allows: both write `name: wallet`. A reader with the documents in
        // hand tells them apart by identity, and the person reading the line
        // has only the line — so the line has to say it too.
        func module(declaring name: String, as identity: Identity) throws -> Module {
            try Module(
                name: "wallet",
                procedures: [
                    name: Procedure(body: [
                        Statement(id: "held", expression: reference("missing"))
                    ])
                ],
                identity: identity,
            )
        }

        // When
        let charge = #expect(throws: ValidationError.self) {
            try Validator().validate(module(declaring: "charge", as: Identity([0x01])))
        }

        let refund = #expect(throws: ValidationError.self) {
            try Validator().validate(module(declaring: "refund", as: Identity([0x02])))
        }

        // Then
        #expect(charge?.place?.rendered == "wallet@01/procedures.charge.body.held[0].value")
        #expect(refund?.place?.rendered == "wallet@02/procedures.refund.body.held[0].value")
    }

    @Test("a shape a named module declares is placed by the key it declared it under")
    func aTypeInANamedModuleIsPlacedByItsDeclaredKey() throws {
        // Given — a named module, whose type keys the link rewrites into the
        // names it calls them by. A place spelled from one of those carries the
        // module's name twice and leads nowhere: `types.wallet.Coin` is not
        // what any document writes.
        let sut = try Module(
            name: "wallet",
            types: ["Coin": .record(["amount": .named("Missing")])],
            procedures: [entryName: Procedure(body: [])],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then
        #expect(error?.place?.rendered == "wallet@d0cf00/types.Coin.amount")
    }

    @Test("a membership a named module declares is placed the same way")
    func aConstraintInANamedModuleIsPlacedByItsDeclaredKey() throws {
        // Given — the other space the qualifying pass rewrites keys in. A
        // membership admitting nothing is refused from the table alone, which
        // is the walk that has only the link's names to go on.
        let sut = try Module(
            name: "wallet",
            constraints: ["Spendable": []],
            procedures: [entryName: Procedure(body: [])],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "wallet.entry")
        }

        // Then
        #expect(error?.place?.rendered == "wallet@d0cf00/constraints.Spendable")
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
        #expect(sut.rendered?.contains(".sent[0].call.") == true)

        // And carried as the language's, beside the keys that are the text's
        #expect(sut.steps.contains(.landmark("call")))
        #expect(sut.steps.contains(.key("call")) == false)
        #expect(sut.steps.contains(.key("arguments")))
    }

    @Test("what a return carries is checked, and placed where the return is")
    func aReturnsValueIsWalked() throws {
        // Given — the door a caller assembling a program itself passes. What
        // `return` carries is an operand like any other: a name it reads has
        // to be visible where it was written.
        // When
        let error = #expect(throws: ValidationError.self) {
            try module(
                refusing: Statement(
                    expression: .leave(Leave(reach: .procedure, value: reference("missing")))
                )
            )
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body[0].return")
    }

    @Test("both stages point at the statement that leaves, not at what follows it")
    func theLeaveRuleIsPlacedOnTheLeavingStatement() throws {
        // Given — the one rule both stages hold: the load catches the leaves
        // the text shows, the link catches the word that declares `never`.
        // What an author has to change is the statement that ends the body, so
        // that is where each of them says it is.
        let declared = try Module(
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
        let load = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(body: [
                        Statement(expression: .leave(Leave(reach: .procedure))),
                        Statement(id: "after", expression: .literal(.int(1)))
                    ])
                ]
            )
        }

        let link = #expect(throws: LinkError.self) {
            try Language().link([declared] + Module.standard, entry: entryName)
        }

        // Then
        #expect(load?.place?.rendered == "procedures.entry.body[0].return")
        #expect(link?.place?.rendered == "procedures.entry.body[0].call")
    }

    @Test("a name two documents declare is refused at the one that could not be added")
    func aDeclarationDeclaredTwiceIsPlacedAtTheSecond() throws {
        // Given — a caller receiving a module from somewhere else appends it to
        // what it already holds and links again. What that link refuses is a
        // collision between two documents, and only the caller knows which file
        // either arrived in — a refusal naming neither sends it opening all of
        // them.
        func declaring(_ procedure: String, as identity: Identity) throws -> Module {
            try Module(
                name: "pricing",
                procedures: [procedure: Procedure(body: [], result: .literal(.int(1)))],
                identity: identity,
            )
        }

        let held = try declaring("taxed", as: Identity([0x01]))
        let sent = try declaring("taxed", as: Identity([0x02]))
        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([held, sent, caller] + Module.standard, entry: entryName)
        }

        // Then — the place is the declaration that cannot be added
        #expect(error?.place?.rendered == "pricing@02/procedures.taxed")

        // And the one it collides with is named, since a place says one thing
        #expect(error?.message.contains("pricing@01") == true)
    }

    @Test("the same document handed to one link twice is refused as that")
    func theSameDocumentHandedTwiceIsRefusedAsOneDocument() throws {
        // Given — a caller that appends what arrives without checking whether
        // it already holds it. An identity is derived from the text, so the two
        // are one document and every name in it collides with itself. Read as a
        // collision between two declarations, the sentence names the same
        // document on both sides and tells the caller nothing it can act on.
        let module = try Module(
            name: "pricing",
            procedures: ["taxed": Procedure(body: [], result: .literal(.int(1)))],
            identity: Identity([0x01]),
        )

        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([module, module, caller] + Module.standard, entry: entryName)
        }

        // Then — what is wrong is the second copy, not anything inside it
        #expect(error?.place?.rendered == "pricing@01")
        #expect(error?.message.contains("twice") == true)
    }

    @Test("a shape two documents declare is placed the same way a procedure is")
    func aTypeDeclaredTwiceIsPlacedAtTheSecond() throws {
        // Given — the same rule in the space a type is resolved in. The two
        // spaces are walked by different code and an author reading either
        // refusal is reading about the same mistake.
        func declaring(_ shape: TypeExpression, as identity: Identity) throws -> Module {
            try Module(name: "pricing", types: ["Money": shape], procedures: [:], identity: identity)
        }

        let held = try declaring(.int, as: Identity([0x01]))
        let sent = try declaring(.string, as: Identity([0x02]))
        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([held, sent, caller] + Module.standard, entry: entryName)
        }

        // Then
        #expect(error?.place?.rendered == "pricing@02/types.Money")
        #expect(error?.message.contains("pricing@01") == true)
    }

    @Test("a name written as a shape in one document and a membership in another")
    func aNameThatIsBothIsPlacedAtTheMembership() throws {
        // Given — the two spaces held against each other, which is the one
        // judgment that reads both tables. The membership is what the walk is
        // standing on when it refuses, so that is what it is addressed to.
        let shape = try Module(name: "pricing", types: ["Money": .int], procedures: [:], identity: Identity([0x01]))

        let membership = try Module(name: "pricing", constraints: ["Money": [.int]], procedures: [:], identity: Identity([0x02]))

        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([shape, membership, caller] + Module.standard, entry: entryName)
        }

        // Then
        #expect(error?.place?.rendered == "pricing@02/constraints.Money")
        #expect(error?.message.contains("pricing@01") == true)
    }

    @Test("constants that name each other are placed at one of the ring, and the same one")
    func aConstantCycleIsPlacedInSortedOrder() throws {
        // Given — a cycle has no first member, so which of them an author is
        // sent to is chosen rather than found. Read off a dictionary it would
        // be a different constant per run, and the two below are written in the
        // order that makes an unsorted answer the likely one.
        let sut = try Module(
            name: "pricing",
            constants: ["zebra": reference("alpha"), "alpha": reference("zebra")],
            procedures: [entryName: Procedure(body: [])],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "pricing.entry")
        }

        // Then
        #expect(error?.place?.rendered == "pricing@d0cf00/const.alpha")
        #expect(error?.message.contains("alpha, zebra") == true)
    }

    @Test("a constant merely blocked by a ring is neither placed nor accused")
    func aConstantWaitingOnARingIsNotOnIt() throws {
        // Given — `aardvark` names one of a ring, so it never settles either
        // and is still waiting when the ring is refused. It is sorted first,
        // which is how it becomes the place if what is waiting is mistaken for
        // what is wrong — and changing it would leave the ring exactly as it
        // is.
        let sut = try Module(
            name: "pricing",
            constants: [
                "aardvark": reference("zebra"),
                "zebra": reference("yak"),
                "yak": reference("zebra")
            ],
            procedures: [entryName: Procedure(body: [])],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "pricing.entry")
        }

        // Then
        #expect(error?.place?.rendered == "pricing@d0cf00/const.yak")
        #expect(error?.message.contains("yak, zebra") == true)
        #expect(error?.message.contains("aardvark") == false)
    }

    @Test("a constant on a circle's edge is not counted as part of it")
    func aConstantReadByACircleIsNotOnIt() throws {
        // Given — `delta` is read by one of a circle and settles perfectly
        // well, so the circle is the only thing wrong here. Narrowing by what
        // nothing reads keeps it anyway, because something does read it.
        let sut = try Module(
            name: "pricing",
            constants: [
                "beta": .dispatch(Dispatch(
                    receiver: reference("gamma"),
                    selector: "plus",
                    arguments: ["value": reference("delta")]
                )),
                "gamma": reference("beta"),
                "delta": reference("epsilon"),
                "epsilon": .literal(.int(1))
            ],
            procedures: [entryName: Procedure(body: [])],
            identity: reading,
        )

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([sut] + Module.standard, entry: "pricing.entry")
        }

        // Then
        #expect(error?.message.contains("beta, gamma") == true)
        #expect(error?.message.contains("delta") == false)
    }

    @Test("two modules nobody wrote down are told apart by where the caller put them")
    func modulesWithNoDocumentAreToldApartByPosition() throws {
        // Given — a caller assembling modules itself. Neither was read from
        // anything, so neither has an identity and both spell the same: the
        // sentence names two documents that read as one, and the place renders
        // without a document at all. Where the caller put them is what is left.
        func declaring() throws -> Module {
            try Module(procedures: ["taxed": Procedure(body: [], result: .literal(.int(1)))])
        }

        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When
        let error = #expect(throws: LinkError.self) {
            try Language().link([declaring(), declaring(), caller] + Module.standard, entry: entryName)
        }

        // Then
        #expect(error?.message.contains("the module at 0 in this link") == true)
        #expect(error?.message.contains("the module at 1 in this link") == true)
    }

    @Test("two words one path spelling could reach are refused at a declaration")
    func aContestedPathWordIsPlacedAtADeclaration() throws {
        // Given — a path segment names no module, so no spelling an author
        // could write would say which of these is meant. The fix is on a
        // declaration, which makes a declaration the place to be sent to.
        func declaring(_ namespace: String, as identity: Identity) throws -> Module {
            try Module(
                name: namespace,
                procedures: [
                    "discounted": Procedure(
                        signature: Signature(
                            receiver: "of",
                            parameters: ["of": Parameter(type: .int)],
                            returns: .int
                        ),
                        body: [],
                        result: reference("of")
                    )
                ],
                identity: identity,
            )
        }

        let catalog = try declaring("catalog", as: Identity([0x01]))
        let pricing = try declaring("pricing", as: Identity([0x02]))
        let shipping = try declaring("shipping", as: Identity([0x03]))
        let caller = try Module(procedures: [entryName: Procedure(body: [])])

        // When — three of them, because a slot holding the latest collision
        // keeps the newest two and drops whoever took the name first. With two
        // there is nothing for a third to push out.
        //
        // Handed over in an order the names do not sort in, since the tables
        // behind this are built in name order and the second declaration is
        // the second the caller handed over.
        let error = #expect(throws: LinkError.self) {
            try Language().link(
                [shipping, catalog, pricing, caller] + Module.standard,
                entry: entryName
            )
        }

        // Then — `catalog` is the second the caller handed over, whatever the
        // three names sort as
        #expect(error?.place?.rendered == "catalog@01/procedures.discounted")

        // And every one of them is named, the first included
        #expect(error?.message.contains("catalog.discounted") == true)
        #expect(error?.message.contains("pricing.discounted") == true)
        #expect(error?.message.contains("shipping.discounted") == true)
    }

    // MARK: - Public
    // MARK: - Private
    // A document to stand in for one that was read. What derives an identity is
    // the wire's, which is a target these tests do not import — and what a place
    // does with one is the same whatever wrote it.
    private let reading = Identity([0xd0, 0xcf, 0x00])

    private func module(
        refusing statement: Statement,
        in identity: Identity? = nil
    ) throws -> Module {
        try Module(
            procedures: [entryName: Procedure(body: [statement])],
            identity: identity
        )
    }

    private func place(refusing statement: Statement) -> Place? {
        let error = #expect(throws: ValidationError.self) {
            try Validator().validate(module(refusing: statement))
        }

        return error?.place
    }
}
