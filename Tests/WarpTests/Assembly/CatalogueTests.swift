//
//  CatalogueTests.swift
//  WarpTests
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// Closing the list a link is handed.
//
// A module asks for what it needs and does not carry it, so a caller holding
// one module does not thereby hold the modules it declares against. The
// catalogue is where a host writes down what it is willing to supply, and
// closing a list against it is what turns "this program" into "this program
// and everything it needs, once each".
@Suite("A catalogue closes the modules a link is handed")
struct CatalogueTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a shape a signature mentions brings the module that declares it")
    func aMentionedShapeBringsItsModule() throws {
        // Given. `shapes` declares the type, `users` declares against it and
        // carries nothing.
        let shapes = try Module(types: ["Age": .int], procedures: [:])
        let users = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("Age")),
                    body: [],
                    result: .literal(.int(7))
                )
            ]
        )

        // When.
        let closed = try Catalogue([shapes]).closing([users])

        // Then. The build has both, and it links.
        #expect(closed.count == 2)
        #expect(try builder.build(closed, entry: entryName).rows[entryName] != nil)
    }

    @Test("a word a body sends brings the module that declares it")
    func aSentWordBringsItsModule() throws {
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(
                        Call(
                            receiver: .literal(.int(1)),
                            selector: "std.math.plus",
                            arguments: ["value": .literal(.int(2))]
                        )
                    )
                )
            ]
        )

        // When. The catalogue holds the whole standard vocabulary; the program
        // names one word of it.
        let closed = try Catalogue(Module.standard).closing([program])

        // Then. `math` came for the word, and `foundation` came after it for
        // the constraint `math`'s own signatures mention.
        #expect(closed.count == 3)
        #expect(try builder.build(closed, entry: entryName).rows["std.math.plus"] != nil)
    }

    @Test("supply handed over as well as held is supply standing twice")
    func supplyListedBesideTheCatalogueStandsTwice() throws {
        let shapes = try Module(types: ["Age": .int], procedures: [:])
        let users = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("Age")),
                    body: [],
                    result: .literal(.int(7))
                )
            ]
        )

        // When. What is asked for is what the caller means to run, so a module
        // handed over here as well as held in the catalogue is in the answer
        // twice.
        let closed = try Catalogue([shapes]).closing([users, shapes])

        // Then. The build says so, rather than the catalogue quietly keeping
        // one of them.
        #expect(closed.count == 3)
        #expect(throws: BuildError.self) { try builder.build(closed, entry: entryName) }
    }

    @Test("a caller cannot supply a granted word to a granted module")
    func aWantedModuleDoesNotStandInForTheCatalogue() throws {
        // Given. `supplier` sends a word the catalogue declares, and the
        // program declares that same word itself.
        let real = try Module(
            procedures: ["app.w": Procedure(body: [], result: .literal(.string("host")))]
        )
        let supplier = try Module(
            procedures: ["lib.run": Procedure(body: [], result: .call(Call(selector: "app.w")))]
        )
        let program = try Module(
            procedures: [
                "app.w": Procedure(body: [], result: .literal(.string("program"))),
                entryName: Procedure(body: [], result: .call(Call(selector: "lib.run")))
            ]
        )

        // When. `supplier` needs the word, so the catalogue's declarer is
        // brought whatever else declares it.
        let closed = try Catalogue([real, supplier]).closing([program])

        // Then. The build meets both and refuses, rather than binding
        // `lib.run` to the word the program wrote.
        #expect(closed.count == 3)
        #expect(throws: BuildError.self) { try builder.build(closed, entry: entryName) }
    }

    @Test("a name the catalogue does not declare is left to the build")
    func anUndeclaredNameIsLeftToTheLink() throws {
        let users = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("Age")),
                    body: [],
                    result: .literal(.int(7))
                )
            ]
        )

        // When. Nothing in the catalogue declares `Age`.
        let closed = try Catalogue([]).closing([users])

        // Then. What comes back is what was asked for, and the refusal is the build's.
        #expect(closed.count == 1)
        #expect(throws: BuildError.self) { try builder.build(closed, entry: entryName) }
    }

    @Test("the caller listing one module twice is not quietly folded")
    func aCallerListingOneModuleTwiceIsNotFolded() throws {
        let shapes = try Module(types: ["Age": .int], procedures: [:])

        // When.
        let closed = try Catalogue([]).closing([shapes, shapes])

        // Then. Both copies stand, and the build says what is wrong with that.
        #expect(closed.count == 2)
        #expect(throws: BuildError.self) { try builder.build(closed, entry: entryName) }
    }

    @Test("two modules declaring one name leave the catalogue no answer")
    func twoModulesDeclaringOneNameAreRefused() throws {
        let mine = try Module(types: ["Age": .int], procedures: [:])
        let theirs = try Module(types: ["Age": .string], procedures: [:])

        #expect(throws: CatalogueError.self) { try Catalogue([mine, theirs]) }
    }

    @Test("the standard vocabulary is a catalogue")
    func theStandardVocabularyIsACatalogue() throws {
        // The bundles shipped with the language declare no name twice between
        // them, so a host can hand the whole list over as what it supplies.
        #expect(throws: Never.self) { try Catalogue(Module.standard) }
    }

    @Test("what a module needs is closed through the modules brought for it")
    func needsAreClosedThroughWhatWasBrought() throws {
        // Given. `program` names a word of `text`, which declares nothing of
        // `foundation` itself but mentions its constraints in signatures.
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(
                        Call(receiver: .literal(.string("a")), selector: "std.text.uppercased")
                    )
                )
            ]
        )

        // When.
        let closed = try Catalogue(Module.standard).closing([program])

        // Then. Whatever came, the build is satisfied by it.
        #expect(throws: Never.self) { try builder.build(closed, entry: entryName) }
    }

    @Test("a claim brings the documents that answer it")
    func aClaimBringsItsWitnesses() throws {
        // Given. Three documents: the type and the claim in one, the contract
        // in another, and the declaration that answers it in a third. The
        // program names the type and never the contract.
        let holding = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            claiming: ["bank.Account": ["app.Describable"]],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: ["app.ask": Procedure(body: [], result: .literal(.null))]
        )
        let answering = try Module(
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("bank.Account")),
                    body: [],
                    result: .cast(
                        .record(["balance": .literal(.int(7))]),
                        as: .named("bank.Account"),
                        optional: false
                    )
                )
            ]
        )

        // When. The program is closed against the catalogue
        let closed = try Catalogue([holding, asking, answering]).closing([program])

        // Then. The document answering the claim came too, and the list links.
        // A claim nothing answers refuses, so a closing that left it out would
        // refuse a program that says nothing about the contract at all
        #expect(closed.count == 4)
        #expect(throws: Never.self) {
            try builder.build(closed + Module.standard, entry: entryName)
        }
    }

    @Test("a claim is followed when the program itself declares the contract")
    func aClaimIsFollowedThroughTheProgramsOwnContract() throws {
        // Given. The catalogue holds the type and the declaration that answers
        // the claim. The contract, and the claim itself, are the program's.
        let holding = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let answering = try Module(
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let program = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claiming: ["bank.Account": ["app.Describable"]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("bank.Account")),
                    body: [],
                    result: .cast(
                        .record(["balance": .literal(.int(7))]),
                        as: .named("bank.Account"),
                        optional: false
                    )
                )
            ]
        )

        // When. The contract is nowhere in the catalogue, so the words a claim
        // is spelled from are read off the answer as it grows
        let closed = try Catalogue([holding, answering]).closing([program])

        // Then
        #expect(closed.count == 3)
        #expect(throws: Never.self) {
            try builder.build(closed + Module.standard, entry: entryName)
        }
    }

    @Test("what a claim brought is asked for its own needs in turn")
    func aClaimsAnswerIsClosedOverToo() throws {
        // Given. The declaration answering the claim names a type no other
        // document does, so what the claim brought has a need of its own. The
        // walk that finds it has already run by the time the claim is
        // followed, so the answer only closes if the two take turns.
        let holding = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            claiming: ["bank.Account": ["app.Describable"]],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: ["app.ask": Procedure(body: [], result: .literal(.null))]
        )
        let spelling = try Module(
            types: ["bank.Wording": .string],
            procedures: ["bank.wording": Procedure(body: [], result: .literal(.null))]
        )
        let answering = try Module(
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .named("bank.Wording")
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("bank.Account")),
                    body: [],
                    result: .cast(
                        .record(["balance": .literal(.int(7))]),
                        as: .named("bank.Account"),
                        optional: false
                    )
                )
            ]
        )

        // When
        let closed = try Catalogue([holding, asking, spelling, answering]).closing([program])

        // Then. The answer came, and so did the type its signature names
        #expect(closed.count == 5)
        #expect(throws: Never.self) {
            try builder.build(closed + Module.standard, entry: entryName)
        }
    }

    @Test("a document's word collides before its shape")
    func aWordCollidesBeforeAShape() throws {
        // Given. One document declaring a word and a type, and a second
        // declaring both of the same names. The catalogue has two answers for
        // each and reports the first it walks into.
        let first = try Module(
            types: ["a.Shape": .record(["x": .int])],
            procedures: ["a.word": Procedure(body: [], result: .literal(.null))]
        )
        let second = try Module(
            types: ["a.Shape": .record(["x": .int])],
            procedures: ["a.word": Procedure(body: [], result: .literal(.null))]
        )

        // When / Then. Words stand before shapes, so the word is the one an
        // author is told about.
        #expect {
            try Catalogue([first, second])
        } throws: { error in
            "\(error)".contains("the word 'a.word' is declared by")
        }
    }
}
