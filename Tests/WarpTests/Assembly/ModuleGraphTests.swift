//
//  ModuleGraphTests.swift
//  WarpTests
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// Standing a link's modules in the order each one's needs stand before it.
//
// A module is compiled against what it needs, so the order is what makes
// compiling one module at a time possible at all. Modules that need each
// other have no such order and are refused here.
@Suite("A module graph stands its modules in the order their needs stand")
struct ModuleGraphTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a module stands after the module whose procedure it sends")
    func aSentProcedureStandsFirst() throws {
        // Given. `caller` sends a procedure `library` declares, handed over in the
        // order that puts the needing one first.
        let library = try Module(
            procedures: [
                "lib.twice": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(2))
                )
            ]
        )
        let caller = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(receiver: .literal(.int(1)), selector: "lib.twice"))
                )
            ]
        )

        // When.
        let graph = try ModuleGraph([caller, library])

        // Then. What is needed stands first.
        #expect(graph.modules.count == 2)
        #expect(graph.modules[0].procedures["lib.twice"] != nil)
        #expect(graph.modules[1].procedures[entryName] != nil)
    }

    @Test("a module stands after the module that declares a type it names")
    func aMentionedTypeStandsFirst() throws {
        let loweredTypes = try Module(types: ["Age": .int], procedures: [:])
        let users = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .named("Age")),
                    body: [],
                    result: .literal(.int(7))
                )
            ]
        )

        let graph = try ModuleGraph([users, loweredTypes])

        #expect(graph.modules[0].types["Age"] != nil)
        #expect(graph.modules[1].procedures[entryName] != nil)
    }

    @Test("modules that need each other have no order, so they are refused")
    func aRingIsRefused() throws {
        // Given. Each sends a procedure the other declares.
        let one = try Module(
            procedures: [
                "one.here": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "two.there"))
                )
            ]
        )
        let two = try Module(
            procedures: [
                "two.there": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "one.here"))
                )
            ]
        )

        // When / Then.
        #expect {
            try ModuleGraph([one, two])
        } throws: { error in
            "\(error)".contains("need each other") && "\(error)".contains("one.here")
        }
    }

    @Test("a module that sends its own procedures stands on nothing")
    func aModuleAloneIsNotARing() throws {
        // Given. Two declarations of one module calling each other, which is
        // recursion inside a module rather than a ring between modules.
        let alone = try Module(
            procedures: [
                "solo.here": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "solo.there"))
                ),
                "solo.there": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then.
        #expect(try ModuleGraph([alone]).modules.count == 1)
    }

    @Test("a name no module here declares is left to the build")
    func anUndeclaredNeedIsNotRefused() throws {
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "nobody.declares"))
                )
            ]
        )

        #expect(try ModuleGraph([program]).modules.count == 1)
    }

    @Test("the standard vocabulary stands whole")
    func theStandardVocabularyStands() throws {
        let graph = try ModuleGraph(Module.standard)

        #expect(graph.modules.count == Module.standard.count)
    }

    // MARK: - Private
}
