//
//  PlaceTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// Where a refusal says the procedures are.
//
// What these hold a place to is that it leads somewhere for the reader it is
// shown to. These programs are assembled in Swift and were never written down,
// so the reader is the caller that built them and the procedures are the language's
// own. A document's would name keys that exist in no file. Reading a place in a
// document's procedures is asked of `WarpSyntax`, which has the document.
//
// The steps are what makes both readings possible: a slot and a construct
// travel as themselves, and only what an author named travels as a procedure.
@Suite
struct PlaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a place is spelled from the language's own names")
    func aPlaceIsSpelledFromTheLanguagesNames() async {
        // Given. A slot a document calls something else. A loop's condition is
        // `where` in a document, and that procedure appears nowhere in what a caller
        // assembling this wrote.
        let spin = place(
            refusing: Statement(binding: .constant("spin"), expression: .loop(
                    while: .block(Block(body: [], result: .literal(.bool(true)))),
                    body: Block(body: []),
                    round: "spin"
                )
            )
        )

        // Then
        #expect(spin?.rendered == "procedures.entry.body.spin[0].loop.condition")
    }

    @Test("what a call is written with is named by the position holding it")
    func anArgumentIsNamedByItsPosition() async {
        // Given. An argument reported from the statement's own place says a
        // thing is wrong and does not say which of the several written there.
        let sut = place(
            refusing: Statement(binding: .constant("sent"), expression: .call(
                    Call(selector: "send", arguments: [reference("missing")])
                )
            )
        )

        // Then
        #expect(sut?.rendered == "procedures.entry.body.sent[0].call.arguments[0]")
    }

    @Test("a statement is found by its name, and by its position when it has none")
    func aStatementIsFoundByWhicheverItHas() async {
        // Given. A statement run for its effect alone fixes no name, and its
        // position is the only thing there is to call it.
        let named = place(refusing: Statement(binding: .constant("held"), expression: reference("missing")))
        let bare = place(refusing: Statement(expression: reference("missing")))

        // Then
        #expect(named?.rendered == "procedures.entry.body.held[0].reference")
        #expect(bare?.rendered == "procedures.entry.body[0].reference")

        // And the name is not all that is kept: a reader mapping a place back
        // to the text it was written in needs the position, which a name would
        // have spent.
        #expect(named?.steps.contains(.statement(name: "held", at: 0)) == true)
    }

    @Test("a signature's slots are named by the position a procedure declares them at")
    func parametersAreNamedByPosition() throws {
        // Given. A parameter shadowing a constant, so the refusal is the
        // declaration's own rather than anything a body did with it
        // When
        let error = #expect(throws: ValidationError.self) {
            try Module(
                constants: ["amount": .literal(.int(1))],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "amount", type: .int)]),
                        body: []
                    )
                ]
            )
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.parameters[0]")
    }

    @Test("the place is carried as data, and the sentence is only the reason")
    func aPlaceIsNotProse() async throws {
        // Given. A place written into the message is a place nothing can read
        // back. A front end holding the file this was authored in has to walk
        // the steps to point at the line, and a sentence has no steps. When
        let error = #expect(throws: ValidationError.self) {
            try module(refusing: Statement(binding: .constant("held"), expression: reference("missing")))
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.held[0].reference")
        #expect(error?.message.contains("procedures.entry") == false)
        #expect(error?.description.hasPrefix("procedures.entry.body.held[0].reference: ") == true)
    }

    @Test("what the build refuses is placed the way what the load refuses is")
    func bothStagesSpellOnePlace() async throws {
        // Given. One document, refused at the build: the two stages walk the
        // same text and an author reading both should not have to learn two
        // spellings of where they are.
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [
                    Statement(binding: .constant("sent"), expression: .call(Call(selector: "nowhere")))
                ])
            ]
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.sent[0].call")
    }

    @Test("the build narrows to the argument it refused, not to the call holding it")
    func aLinkRefusalNarrowsToTheArgument() async throws {
        // Given. A call written with several arguments, one of which holds what
        // the declaration does not take. Reported from the call, an author is
        // told a thing is wrong and not which of the three it is.
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [
                    Statement(binding: .constant("sent"), expression: .call(
                            Call(
                                selector: "helper",
                                arguments: [.literal(.int(1)), .literal(.string("two")), .literal(.int(3))]
                            )
                        )
                    )
                ]),
                "helper": Procedure(
                    signature: Signature(parameters: [
                        Parameter(name: "first", type: .int),
                        Parameter(name: "second", type: .int),
                        Parameter(name: "third", type: .int)
                    ]),
                    body: []
                )
            ]
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(
            error?.place?.rendered == "procedures.entry.body.sent[0].call.arguments[1]"
        )
    }

    @Test("one place, whichever stage walked the text")
    func theTwoStagesSpellOneSlotOneWay() async throws {
        // Given. The same slot of the same statement, reached once by the walk
        // that checks a document against itself and once by the walk that
        // resolves its names. Two spellings of one place is two documents as
        // far as an author following the procedures is concerned.
        let linked = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [
                    Statement(binding: .constant("sent"), expression: .call(
                            Call(selector: "helper", arguments: [.literal(.string("x"))])
                        )
                    )
                ]),
                "helper": Procedure(
                    signature: Signature(parameters: [Parameter(name: "amount", type: .int)]),
                    body: []
                )
            ]
        )

        // When
        let load = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(access: .public, body: [
                        Statement(binding: .constant("sent"), expression: .call(
                                Call(selector: "helper", arguments: [reference("missing")])
                            )
                        )
                    ])
                ]
            )
        }

        let link = await #expect(throws: BuildError.self) {
            try await Builder().build([linked] + Module.standard)
        }

        // Then
        #expect(load?.place?.rendered == "procedures.entry.body.sent[0].call.arguments[0]")
        #expect(link?.place?.rendered == "procedures.entry.body.sent[0].call.arguments[0]")
    }

    @Test("every walk that reports a place steps through the same slots to reach one")
    func theWalksAgreeOnHowDeepASlotIs() async throws {
        // Given. One call, held under an attempt's rescue: a slot no walk
        // reaches without stepping through the keys between. Four walks report
        // places and each destructures the language for itself, so what one of
        // them forgets to step into is a place that reads like another one.
        //
        // Each of them is made to speak about this call in the way only it can:
        // a name nothing declares for the walk that checks the document against
        // itself, a procedure nothing declares for the walk that resolves names, a
        // claim the types already prove for the walk that reads them.
        let reached = "procedures.entry.body.guarded[0].attempt.rescue.body.sent[0].call"

        func module(sending selector: Name, with argument: Warp.Expression) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(access: .public, body: [
                        Statement(binding: .constant("guarded"), expression: .attempt(
                                Block(body: [mayFail()]),
                                rescue: Block(body: [
                                    Statement(binding: .constant("sent"), expression: .call(
                                            Call(selector: selector, arguments: [argument])
                                        )
                                    )
                                ]),
                                failure: "guarded"
                            )
                        )
                    ]),
                    "helper": Procedure(
                        signature: Signature(parameters: [Parameter(name: "amount", type: .int)]),
                        body: []
                    )
                ]
            )
        }

        // When
        let load = #expect(throws: ValidationError.self) {
            try Validator().validate(module(sending: "helper", with: reference("missing")))
        }

        let bound = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [module(sending: "nowhere", with: .literal(.int(1)))] + Module.standard
            )
        }

        let typed = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [module(
                    sending: "helper",
                    with: .cast(.literal(.int(1)), as: .int, optional: false)
                )] + Module.standard
            )
        }

        // Then. Each says something different about the call, from one place
        #expect(load?.place?.rendered?.hasPrefix(reached) == true)
        #expect(bound?.place?.rendered?.hasPrefix(reached) == true)
        #expect(typed?.place?.rendered?.hasPrefix(reached) == true)

        // And the walk that only gathers puts it in the same place
        let gathered = try await #require(
            module(sending: "helper", with: .literal(.int(1)))
                .procedures[entryName]?.block?
                .subexpressions(at: .procedure(entryName.spelling, in: .assembled))
                .first { _, expression in
                    guard case .call = expression else { return false }

                    return true
                }
        )

        #expect(gathered.0.rendered == reached)
    }

    @Test("a declared spelling with a dot in it is one key in the place")
    func aDottedSpellingIsOneKey() async throws {
        // Given. The same refusal from a declaration spelled `wallet.entry`.
        // The dot is part of the key the document wrote, so the place holds
        // that key whole rather than two steps.
        let sut = try Module(
            procedures: [
                "wallet.entry": Procedure(body: [
                    Statement(binding: .constant("sent"), expression: .call(Call(selector: "nowhere")))
                ])
            ],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.document == Place.Document(identity: reading))
        #expect(error?.place?.steps.contains(.key("wallet.entry")) == true)
        #expect(error?.place?.rendered == "d0cf00/procedures.wallet.entry.body.sent[0].call")
    }

    @Test("a program nobody wrote down says so, rather than saying no name")
    func anAssembledProgramNamesNoDocument() async {
        // Given. The same program twice: once handed in as a caller assembling
        // one in memory holds it, and once read out of a document. There is no
        // text under the first, which is a different fact from a text that
        // wrote no name. Reading them as one would match a program nobody wrote
        // against a file somebody did, and answer with that file's line.
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
        #expect(read?.place?.document == Place.Document(identity: reading))
    }

    @Test("two documents are told apart by identity in the line too")
    func twoDocumentsAreToldApartInTheLine() {
        // Given. Two documents. A reader with them in hand tells them apart by
        // identity, and the person reading the line has only the line, so the
        // line says it too.
        func module(declaring name: Name, as identity: Identity) throws -> Module {
            try Module(
                procedures: [
                    name: Procedure(body: [
                        Statement(binding: .constant("held"), expression: reference("missing"))
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
        #expect(charge?.place?.rendered == "01/procedures.charge.body.held[0].reference")
        #expect(refund?.place?.rendered == "02/procedures.refund.body.held[0].reference")
    }

    @Test("a type is placed by the key it was declared under, dot and all")
    func aTypeIsPlacedByItsDeclaredKey() async throws {
        // Given. A type declared as `wallet.Coin`. The place is spelled from
        // that key, which is what the document writes.
        let sut = try Module(
            types: ["wallet.Coin": .record(["amount": .named("Missing")])],
            procedures: [entryName: Procedure(access: .public, body: [])],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "d0cf00/types.wallet.Coin.fields.amount")
    }

    @Test("a membership is placed the same way")
    func aConstraintIsPlacedByItsDeclaredKey() async throws {
        // Given. The other space. A membership admitting nothing is refused
        // from the table alone, which is the walk that has only the declared
        // keys to go on.
        let sut = try Module(
            constraints: ["wallet.Spendable": []],
            procedures: [entryName: Procedure(access: .public, body: [])],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "d0cf00/constraints.wallet.Spendable")
    }

    @Test("a statement's construct is the language's name, and says so")
    func aConstructIsNotClaimedAsTheDocumentsOwn() async throws {
        // Given. One construct, two texts: `{ call: … }` and `{ value: { call: … }
        // }` are both a call by the time anything here sees one, so the
        // name for the construct is this implementation's rather than something
        // a reader may go looking for in a file.
        let sut = try #require(
            place(
                refusing: Statement(binding: .constant("sent"), expression: .call(
                        Call(selector: "send", arguments: [reference("missing")])
                    )
                )
            )
        )

        // Then. The procedure is spelled for the person reading the line
        #expect(sut.rendered?.contains(".sent[0].call.") == true)

        // And carried as the type rather than as any procedure, so the side that
        // spells it is the side that knows what its reader is looking at
        #expect(sut.steps.contains(.construct(.call)))
        #expect(sut.steps.contains(.part(.arguments)))

        // Where the argument stands is carried as the position it was written at
        #expect(sut.steps.contains(.index(0)))
        #expect(sut.steps.contains(.key("call")) == false)
    }

    @Test("what a return carries is checked, and placed where the return is")
    func aReturnsValueIsWalked() async throws {
        // Given. The door a caller assembling a program itself passes. What
        // `return` carries is an operand like any other: a name it reads has to
        // be visible where it was written. When
        let error = #expect(throws: ValidationError.self) {
            try module(
                refusing: Statement(
                    expression: .leave(Leave(reach: .procedure, value: reference("missing")))
                )
            )
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body[0].leave")
    }

    @Test("both stages point at the statement that leaves, not at what follows it")
    func theLeaveRuleIsPlacedOnTheLeavingStatement() async throws {
        // Given. The one rule both stages hold: the load catches the leaves the
        // text shows, the build catches the procedure that declares `never`. What an
        // author has to change is the statement that ends the body, so that is
        // where each of them says it is.
        let declared = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [
                    Statement(
                        expression: .call(
                            Call(selector: "stop", arguments: [.literal(.string("x"))])
                        )
                    ),
                    Statement(binding: .constant("after"), expression: .literal(.int(1)))
                ]),
                "stop": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "message", type: .string)],
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
                    entryName: Procedure(access: .public, body: [
                        Statement(expression: .leave(Leave(reach: .procedure))),
                        Statement(binding: .constant("after"), expression: .literal(.int(1)))
                    ])
                ]
            )
        }

        let link = await #expect(throws: BuildError.self) {
            try await Builder().build([declared] + Module.standard)
        }

        // Then
        #expect(load?.place?.rendered == "procedures.entry.body[0].leave")
        #expect(link?.place?.rendered == "procedures.entry.body[0].call")
    }

    @Test("a name two documents declare is refused at the one that could not be added")
    func aDeclarationDeclaredTwiceIsPlacedAtTheSecond() async throws {
        // Given. A caller receiving a module from somewhere else appends it to
        // what it already holds and links again. What that link refuses is a
        // collision between two documents, and only the caller knows which file
        // either arrived in. A refusal naming neither sends it opening all of
        // them.
        func declaring(_ procedure: Name, as identity: Identity) throws -> Module {
            try Module(
                procedures: [procedure: Procedure(body: [], result: .literal(.int(1)))],
                identity: identity,
            )
        }

        let held = try declaring("taxed", as: Identity([0x01]))
        let sent = try declaring("taxed", as: Identity([0x02]))
        let caller = try Module(procedures: [entryName: Procedure(access: .public, body: [])])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([held, sent, caller] + Module.standard)
        }

        // Then. The place is the declaration that cannot be added
        #expect(error?.place?.rendered == "02/procedures.taxed")

        // And the one it collides with is named, since a place says one thing
        #expect(error?.message.contains("by 01") == true)
    }

    @Test("the same document handed to one link twice is refused as that")
    func theSameDocumentHandedTwiceIsRefusedAsOneDocument() async throws {
        // Given. A caller that appends what arrives without checking whether it
        // already holds it. An identity is derived from the text, so the two
        // are one document and every name in it collides with itself. Read as a
        // collision between two declarations, the sentence names the same
        // document on both sides and tells the caller nothing it can act on.
        let module = try Module(
            procedures: ["pricing.taxed": Procedure(body: [], result: .literal(.int(1)))],
            identity: Identity([0x01]),
        )

        let caller = try Module(procedures: [entryName: Procedure(access: .public, body: [])])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([module, module, caller] + Module.standard)
        }

        // Then. What is wrong is the second copy, not anything inside it
        #expect(error?.place?.rendered == "01")
        #expect(error?.message.contains("twice") == true)
    }

    @Test("a type two documents declare is placed the same way a procedure is")
    func aTypeDeclaredTwiceIsPlacedAtTheSecond() async throws {
        // Given. The same rule in the space a type is resolved in. The two
        // spaces are walked by different code and an author reading either
        // refusal is reading about the same mistake.
        func declaring(_ type: TypeExpression, as identity: Identity) throws -> Module {
            try Module(types: ["pricing.Money": type], procedures: [:], identity: identity)
        }

        let held = try declaring(.int, as: Identity([0x01]))
        let sent = try declaring(.string, as: Identity([0x02]))
        let caller = try Module(procedures: [entryName: Procedure(access: .public, body: [])])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([held, sent, caller] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "02/types.pricing.Money")
        #expect(error?.message.contains("by 01") == true)
    }

    @Test("a name written as a type in one document and a membership in another")
    func aNameThatIsBothIsPlacedAtTheMembership() async throws {
        // Given. The two tables held against each other, which is the one
        // judgment that reads both tables. The membership is what the walk is
        // standing on when it refuses, so that is what it is addressed to.
        let type = try Module(types: ["pricing.Money": .int], procedures: [:], identity: Identity([0x01]))

        let membership = try Module(constraints: ["pricing.Money": [.int]], procedures: [:], identity: Identity([0x02]))

        let caller = try Module(procedures: [entryName: Procedure(access: .public, body: [])])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([type, membership, caller] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "02/constraints.pricing.Money")
        #expect(error?.message.contains("01") == true)
    }

    @Test("constants that name each other are placed at one of the ring, and the same one")
    func aConstantCycleIsPlacedInSortedOrder() async throws {
        // Given. A cycle has no first member, so which of them an author is
        // sent to is chosen rather than found. Read off a dictionary it would
        // be a different constant per run, and the two below are written in the
        // order that makes an unsorted answer the likely one.
        let sut = try Module(
            constants: ["zebra": reference("alpha"), "alpha": reference("zebra")],
            procedures: [entryName: Procedure(access: .public, body: [])],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "d0cf00/constants.alpha")
        #expect(error?.message.contains("alpha, zebra") == true)
    }

    @Test("a constant merely blocked by a ring is neither placed nor accused")
    func aConstantWaitingOnARingIsNotOnIt() async throws {
        // Given. `aardvark` names one of a ring, so it never settles either and
        // is still waiting when the ring is refused. It is sorted first, which
        // is how it becomes the place if what is waiting is mistaken for what
        // is wrong, and changing it would leave the ring exactly as it is.
        let sut = try Module(
            constants: [
                "aardvark": reference("zebra"),
                "zebra": reference("yak"),
                "yak": reference("zebra")
            ],
            procedures: [entryName: Procedure(access: .public, body: [])],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.place?.rendered == "d0cf00/constants.yak")
        #expect(error?.message.contains("yak, zebra") == true)
        #expect(error?.message.contains("aardvark") == false)
    }

    @Test("a constant on a cycle's edge is not counted as part of it")
    func aConstantReadByACycleIsNotOnIt() async throws {
        // Given. `delta` is read by one of a cycle and settles perfectly well,
        // so the cycle is the only thing wrong here. Narrowing by what nothing
        // reads keeps it anyway, because something does read it.
        let sut = try Module(
            constants: [
                "beta": .call(Call(selector: "std.math.plus", arguments: [reference("gamma"), reference("delta")])),
                "gamma": reference("beta"),
                "delta": reference("epsilon"),
                "epsilon": .literal(.int(1))
            ],
            procedures: [entryName: Procedure(access: .public, body: [])],
            identity: reading,
        )

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }

        // Then
        #expect(error?.message.contains("beta, gamma") == true)
        #expect(error?.message.contains("delta") == false)
    }

    @Test("two modules nobody wrote down are told apart by where the caller put them")
    func modulesWithNoDocumentAreToldApartByPosition() async throws {
        // Given. A caller assembling modules itself. Neither was read from
        // anything, so neither has an identity and both spell the same: the
        // sentence names two documents that read as one, and the place renders
        // without a document at all. Where the caller put them is what is left.
        func declaring() throws -> Module {
            try Module(procedures: ["taxed": Procedure(body: [], result: .literal(.int(1)))])
        }

        let caller = try Module(procedures: [entryName: Procedure(access: .public, body: [])])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([declaring(), declaring(), caller] + Module.standard)
        }

        // Then
        #expect(error?.message.contains("the module at 0 in this link") == true)
        #expect(error?.message.contains("the module at 1 in this link") == true)
    }

    // MARK: - Public
    // MARK: - Private
    // A document to stand in for one that was read. What derives an identity is
    // the wire's, which is a target these tests do not import, and what a place
    // does with one is the same whatever wrote it.
    private let reading = Identity([0xd0, 0xcf, 0x00])

    private func module(
        refusing statement: Statement,
        in identity: Identity? = nil
    ) throws -> Module {
        try Module(
            procedures: [entryName: Procedure(access: .public, body: [statement])],
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
