//
//  CompiledTests.swift
//  WarpTests
//
//  Created by JSilver on 9/8/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// The boundary between compiling a world and linking one.
//
// Compiling settles what the documents say on their own. Linking takes that
// and one name to start from. What each stage may do is what these ask.
@Suite("What compiling settles and what linking decides")
struct CompiledTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Initializer
    // MARK: - Test
    @Test("one world compiled once answers every entry asked of it")
    func oneCompileAnswersManyEntries() throws {
        // Given. Two entries, neither reaching the other.
        let sut = try Module(
            procedures: [
                "app.here": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.there": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        // When. Compiled once, linked twice.
        let compiled = try linker.compile([sut] + Module.standard)

        // Then. Each image starts where it was asked to.
        #expect(try linker.link(compiled, entry: "app.here").start == compiled.rows["app.here"])
        #expect(try linker.link(compiled, entry: "app.there").start == compiled.rows["app.there"])
    }

    @Test("what a document says holds whichever entry a caller names")
    func judgementDoesNotDependOnTheEntry() throws {
        // Given. A declaration nothing reaches, calling a word nobody declares.
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: [], result: .literal(.int(1))),
                "app.stray": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "nobody.declares"))
                )
            ]
        )

        // When / Then. Compiling refuses, and no entry was named to refuse it.
        #expect(throws: LinkError.self) {
            try linker.compile([sut] + Module.standard)
        }
    }

    @Test("a declaration an entry never calls is not reported as reached")
    func reachIsStillTheEntrysOwn() throws {
        let sut = try Module(
            procedures: [
                entryName: Procedure(body: [], result: .literal(.int(1))),
                "app.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        let image = try linker.link(try linker.compile([sut] + Module.standard), entry: entryName)

        #expect(image.reached.contains(entryName))
        #expect(!image.reached.contains("app.aside"))
    }

    @Test("an entry no module declares is refused by the link and not by the compile")
    func anUnknownEntryIsTheLinksRefusal() throws {
        let sut = try Module(
            procedures: [entryName: Procedure(body: [], result: .literal(.int(1)))]
        )

        let compiled = try linker.compile([sut] + Module.standard)

        #expect(throws: LinkError.self) {
            try linker.link(compiled, entry: "app.nowhere")
        }
    }

    @Test("a document's declarations take a run of rows rather than scattering")
    func aDocumentTakesABlockOfRows() throws {
        // Given. Two documents whose spellings interleave in name order, so a
        // table sorted by name alone would scatter both.
        let first = try Module(
            procedures: [
                "a.one": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "c.three": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )
        let second = try Module(
            procedures: [
                "b.two": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "d.four": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(4)))
            ]
        )

        // When.
        let rows = try linker.compile([first, second]).rows

        // Then. Each document's rows are next to each other, and in name
        // order inside the run.
        let ours = try #require(rows["a.one"])

        #expect(rows["c.three"] == ours + 1)
        #expect(rows["b.two"] == ours + 2)
        #expect(rows["d.four"] == ours + 3)
    }

    @Test("a fact nobody declared crosses documents in the order they stand")
    func aDerivedFactCrossesDocuments() throws {
        // Given. Three documents in a chain. The bottom one reads its own
        // variable, so it answers by the run's state rather than on its own,
        // and the two above reach it only through each other.
        let bottom = try Module(
            variables: ["low.count": .literal(.int(0))],
            procedures: [
                "low.read": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("low.count")])
                )
            ]
        )
        let middle = try Module(
            procedures: [
                "mid.ask": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "low.read"))
                )
            ]
        )
        let top = try Module(
            procedures: [
                "top.ask": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "mid.ask"))
                ),
                "top.alone": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        // When. Handed over with the one that is needed last, so the standing
        // has to put it first for the answer to be there when it is asked.
        let compiled = try linker.compile([top, middle, bottom])

        func purity(of declared: Name) throws -> Purity {
            try compiled.table[#require(compiled.rows[declared])].purity
        }

        // Then. The whole chain answers by the run, and what reaches none of
        // it still answers on its own.
        #expect(try purity(of: "low.read") == .unstated)
        #expect(try purity(of: "mid.ask") == .unstated)
        #expect(try purity(of: "top.ask") == .unstated)
        #expect(try purity(of: "top.alone") == .pure)
    }

    // MARK: - Private
}
