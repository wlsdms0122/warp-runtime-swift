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
@Suite("A catalogue closes the world a link is handed")
struct CatalogueTests {
    // MARK: - Property
    private let linker = Linker()

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
        let world = try Catalogue([shapes]).world(for: [users])

        // Then. The link has both, and it links.
        #expect(world.count == 2)
        #expect(try linker.link(world, entry: entryName).rows[entryName] != nil)
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
        let world = try Catalogue(Module.standard).world(for: [program])

        // Then. `math` came for the word, and `foundation` came after it for
        // the constraint `math`'s own signatures mention.
        #expect(world.count == 3)
        #expect(try linker.link(world, entry: entryName).rows["std.math.plus"] != nil)
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
        // handed over here as well as held in the catalogue is in the world
        // twice.
        let world = try Catalogue([shapes]).world(for: [users, shapes])

        // Then. The link says so, rather than the catalogue quietly keeping
        // one of them.
        #expect(world.count == 3)
        #expect(throws: LinkError.self) { try linker.link(world, entry: entryName) }
    }

    @Test("a word a path steps to brings the module that declares it")
    func aWalkedWordBringsItsModule() throws {
        // Given. Nothing is called: the body walks a path, and the last step
        // is a word. `imports` does not hold it, and rightly, since a path
        // reaches only words that answer without running.
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["items": Parameter(type: .array(.int))],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("items"), .key("count")])
                )
            ]
        )

        #expect(program.imports.isEmpty)

        // When.
        let world = try Catalogue(Module.standard).world(for: [program])

        // Then. The module declaring the word came, and the link is satisfied.
        #expect(throws: Never.self) { try linker.link(world, entry: entryName) }
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
        let world = try Catalogue([real, supplier]).world(for: [program])

        // Then. The link meets both and refuses, rather than binding
        // `lib.run` to the word the program wrote.
        #expect(world.count == 3)
        #expect(throws: LinkError.self) { try linker.link(world, entry: entryName) }
    }

    @Test("a name the catalogue does not declare is left to the link")
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
        let world = try Catalogue([]).world(for: [users])

        // Then. The world is what was asked for, and the refusal is the link's.
        #expect(world.count == 1)
        #expect(throws: LinkError.self) { try linker.link(world, entry: entryName) }
    }

    @Test("the caller listing one module twice is not quietly folded")
    func aCallerListingOneModuleTwiceIsNotFolded() throws {
        let shapes = try Module(types: ["Age": .int], procedures: [:])

        // When.
        let world = try Catalogue([]).world(for: [shapes, shapes])

        // Then. Both copies stand, and the link says what is wrong with that.
        #expect(world.count == 2)
        #expect(throws: LinkError.self) { try linker.link(world, entry: entryName) }
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
        let world = try Catalogue(Module.standard).world(for: [program])

        // Then. Whatever came, the link is satisfied by it.
        #expect(throws: Never.self) { try linker.link(world, entry: entryName) }
    }
}
