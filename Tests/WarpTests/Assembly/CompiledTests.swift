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

// The boundary between compiling a module graph and linking one.
//
// Compiling settles what the documents say on their own. Linking takes that
// and one name to start from. What each stage may do is what these ask.
@Suite("What compiling settles and what linking decides")
struct CompiledTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Initializer
    // MARK: - Test
    @Test("one graph compiled once answers every entry asked of it")
    func oneCompileAnswersManyEntries() throws {
        // Given. Two entries, neither reaching the other.
        let sut = try Module(
            procedures: [
                "app.here": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.there": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        // When. Compiled once, linked twice.
        let compiled = try compiled([sut] + Module.standard)

        // Then. Each image starts where it was asked to.
        #expect(try linker.link(compiled, entry: "app.here").start == compiled.assembled().rows["app.here"])
        #expect(try linker.link(compiled, entry: "app.there").start == compiled.assembled().rows["app.there"])
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
            try compiled([sut] + Module.standard)
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

        let image = try linker.link(try compiled([sut] + Module.standard), entry: entryName)

        #expect(image.reached.contains(entryName))
        #expect(!image.reached.contains("app.aside"))
    }

    @Test("an entry no module declares is refused by the link and not by the compile")
    func anUnknownEntryIsTheLinksRefusal() throws {
        let sut = try Module(
            procedures: [entryName: Procedure(body: [], result: .literal(.int(1)))]
        )

        let compiled = try compiled([sut] + Module.standard)

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
        let rows = try compiled([first, second]).assembled().rows

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
        let compiled = try compiled([top, middle, bottom])

        func purity(of declared: Name) throws -> Purity {
            try compiled.assembled().table[#require(compiled.assembled().rows[declared])].purity
        }

        // Then. The whole chain answers by the run, and what reaches none of
        // it still answers on its own.
        #expect(try purity(of: "low.read") == .unstated)
        #expect(try purity(of: "mid.ask") == .unstated)
        #expect(try purity(of: "top.ask") == .unstated)
        #expect(try purity(of: "top.alone") == .pure)
    }

    @Test("a document's types take a run of shape rows behind the ones it names")
    func aDocumentTakesABlockOfShapeRows() throws {
        // Given. The naming document is handed over first, so only the
        // standing can put what it names behind it.
        let naming = try Module(
            types: ["z.Wraps": .named("a.Held"), "z.Also": .named("a.Held")],
            procedures: [
                entryName: Procedure(signature: Signature(returns: .named("z.Wraps")), body: [], result: .literal(.int(1)))
            ]
        )
        let held = try Module(types: ["a.Held": .int], procedures: [:])

        // When.
        let shapes = try compiled([naming, held]).types.shapes

        // Then. The named document's rows come first, and the naming
        // document's are a run of their own after them.
        let row = { (declared: Name) in shapes.labels.firstIndex(of: declared) }

        #expect(try #require(row("a.Held")) < #require(row("z.Also")))
        #expect(try #require(row("z.Also")) + 1 == #require(row("z.Wraps")))
    }

    @Test("compiling leaves which types answer a contract to the link")
    func aContractCallIsFilledAtTheLink() throws {
        // Given. A word calling through a contract, and two types answering it
        // from a document that word never names.
        let sut = try describing()

        // When. Compiled.
        let compiled = try compiled(sut + Module.standard)

        // Then. The call names the contract's word and no row.
        let compiledCall = try dispatch(in: code(of: "app.tell", in: compiled))

        #expect(compiledCall.contract == "app.Describable")
        #expect(compiledCall.word == "describe")
        #expect(compiledCall.calls.isEmpty)

        // And. Linking fills one call for every type that answers.
        let image = try linker.link(compiled, entry: entryName)
        let linkedCall = try dispatch(in: code(of: "app.tell", in: image))

        #expect(Set(linkedCall.calls.keys) == ["bank.Account", "bank.Card"])
    }

    @Test("a type answering a contract from a document the caller never names")
    func aWitnessOutsideTheCallersReachAnswers() async throws {
        // Given / When / Then. Both answered, and the word that called them
        // mentions neither type.
        #expect(try await run(try describing()) == .array([.string("balance 7"), .string("card 42")]))
    }

    @Test("a document numbers its calls from itself, and the link answers with rows")
    func aCallCarriesTheDocumentsOwnNumber() throws {
        // Given. A document calling a word it does not declare.
        let sut = try calling()

        // When. Compiled.
        let compiled = try compiled(sut + Module.standard)

        // Then. The call stands where the caller's imports put it, which is
        // not the row the graph gave the callee.
        let number = try called(in: code(of: "b.asks", in: compiled))

        #expect(number == 0)
        #expect(number != compiled.assembled().rows["a.answers"])

        // And. The link answers with the row.
        let image = try linker.link(compiled, entry: entryName)

        #expect(try called(in: code(of: "b.asks", in: image)) == image.rows["a.answers"])
    }

    @Test("what a document lowers to does not move when the link grows")
    func loweredNumbersDoNotFollowTheGraph() throws {
        // Given. The same two documents, compiled once alone and once beside a
        // third whose declarations sort in front of theirs.
        let sut = try calling()
        let ahead = try Module(
            procedures: [
                "aaa.first": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(0)))
            ]
        )

        // When.
        let alone = try compiled(sut + Module.standard)
        let beside = try compiled([ahead] + sut + Module.standard)

        // Then. The rows moved and the number the body carries did not.
        #expect(alone.assembled().rows["a.answers"] != beside.assembled().rows["a.answers"])
        #expect(
            try called(in: code(of: "b.asks", in: alone))
                == called(in: code(of: "b.asks", in: beside))
        )
    }

    @Test("a document's block is its own, whatever else the link holds")
    func aDocumentsBlockDoesNotFollowTheGraph() throws {
        // Given. The same two documents, compiled once alone and once beside a
        // third whose declarations sort in front of theirs.
        let sut = try calling()
        let ahead = try Module(
            procedures: [
                "aaa.first": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(0)))
            ]
        )

        // When.
        let alone = try compiled(sut + Module.standard)
        let beside = try compiled([ahead] + sut + Module.standard)

        // Then. The rows moved, and the block the document holds did not: the
        // same spellings in the same order, and its closures behind them.
        #expect(alone.assembled().rows["b.asks"] != beside.assembled().rows["b.asks"])
        #expect(try block(holding: "b.asks", in: alone) == block(holding: "b.asks", in: beside))
    }

    @Test("a cast carries the number its own document gave the type")
    func aCastCarriesTheDocumentsOwnShapeNumber() throws {
        // Given. A document casting to a type it declares.
        let sut = try casting()

        // When. Compiled.
        let compiled = try compiled(sut + Module.standard)

        // Then. The cast stands on the document's own number.
        let number = try #require(cast(in: code(of: entryName, in: compiled)).row)

        #expect(number == 0)

        // And. The link answers with the row of its own table.
        let image = try linker.link(compiled, entry: entryName)

        #expect(
            try cast(in: code(of: entryName, in: image)).row
                == compiled.types.shapes.row(named: "bank.Account")
        )
    }

    @Test("what a document stands on does not move when the link grows")
    func loweredShapesDoNotFollowTheGraph() throws {
        // Given. The same document, compiled once alone and once beside one
        // whose type takes a row in front of its own.
        let sut = try casting()
        let ahead = try Module(
            types: ["aaa.Ahead": .record(["first": .int])],
            procedures: [
                "aaa.first": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(0)))
            ]
        )

        // When.
        let alone = try compiled(sut + Module.standard)
        let beside = try compiled([ahead] + sut + Module.standard)

        // Then. The row moved and the number the cast stands on did not.
        #expect(
            alone.types.shapes.row(named: "bank.Account")
                != beside.types.shapes.row(named: "bank.Account")
        )
        #expect(
            try cast(in: code(of: entryName, in: alone)).row
                == cast(in: code(of: entryName, in: beside)).row
        )
    }

    // MARK: - Private
    // Compiling a whole graph: what the list answers first, then the
    // documents against it.
    private func compiled(_ modules: [Module]) throws -> Compiled {
        try linker.compile(modules, in: linker.gathering(of: modules))
    }

    // The block a document holds, by a spelling it declares: what it declared
    // in the order its rows stand, and what each of those rows is called.
    private func block(
        holding declared: Name,
        in compiled: Compiled
    ) throws -> (declared: [Name], rows: [Name]) {
        let document = try #require(
            compiled.documents.first { document in document.declared.contains(declared) }
        )

        return (document.declared, document.table.map(\.label))
    }

    // What a declaration's row holds, whichever table it was read out of.
    private func code(of declared: Name, in compiled: Compiled) throws -> Linked.Implementation {
        let assembled = compiled.assembled()

        return try assembled.table[#require(assembled.rows[declared])].implementation
    }

    private func code(of declared: Name, in image: Image) throws -> Linked.Implementation {
        try image.linked[#require(image.rows[declared])].implementation
    }

    // The shape the cast in a row's result stands on.
    private func cast(in implementation: Linked.Implementation) throws -> Shape {
        guard
            case let .body(body, _) = implementation,
            case let .cast(_, shape, _)? = body.result
        else {
            throw LinkError("the entry holds no cast", at: nil)
        }

        return shape
    }

    // One document declaring a type and casting to it.
    private func casting() throws -> [Module] {
        [
            try Module(
                types: ["bank.Account": .record(["balance": .int])],
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .cast(
                            .record(["balance": .literal(.int(7))]),
                            as: .named("bank.Account"),
                            optional: false
                        )
                    )
                ]
            )
        ]
    }

    // The call through a contract a row's result holds.
    private func dispatch(in implementation: Linked.Implementation) throws -> DispatchOperation {
        guard
            case let .body(body, _) = implementation,
            case let .dispatch(dispatch)? = body.result
        else {
            throw LinkError("'app.tell' holds no call through a contract", at: nil)
        }

        return dispatch
    }

    // Two documents. The first declares the contract and the word calling
    // through it; the second declares the types answering, and the first names
    // neither of them.
    private func describing() throws -> [Module] {
        [
            try Module(
                contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
                procedures: [
                    "app.tell": Procedure(
                        signature: Signature(
                            receiver: "it",
                            parameters: [
                                "it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))
                            ],
                            returns: .string
                        ),
                        body: [],
                        result: .call(
                            Call(receiver: reference("it"), selector: "app.Describable.describe")
                        )
                    )
                ]
            ),
            try Module(
                walked: ["std.collection.last"],
                types: [
                    "bank.Account": .record(["balance": .int]),
                    "bank.Card": .record(["last": .string])
                ],
                procedures: [
                    entryName: Procedure(
                        body: [
                            Statement(
                                binding: .constant("account"),
                                expression: .cast(
                                    .record(["balance": .literal(.int(7))]),
                                    as: .named("bank.Account"),
                                    optional: false
                                )
                            ),
                            Statement(
                                binding: .constant("card"),
                                expression: .cast(
                                    .record(["last": .literal(.string("42"))]),
                                    as: .named("bank.Card"),
                                    optional: false
                                )
                            )
                        ],
                        result: .array([
                            .call(Call(receiver: reference("account"), selector: "app.tell")),
                            .call(Call(receiver: reference("card"), selector: "app.tell"))
                        ])
                    ),
                    "bank.Account.describe": Procedure(
                        signature: Signature(
                            receiver: "of",
                            parameters: ["of": Parameter(type: .named("bank.Account"))],
                            returns: .string
                        ),
                        body: [],
                        result: interpolated(
                            literal("balance "),
                            spelling(.reference([.key("of"), .key("balance")]))
                        )
                    ),
                    "bank.Card.describe": Procedure(
                        signature: Signature(
                            receiver: "of",
                            parameters: ["of": Parameter(type: .named("bank.Card"))],
                            returns: .string
                        ),
                        body: [],
                        result: interpolated(
                            literal("card "),
                            spelling(.reference([.key("of"), .key("last")]))
                        )
                    )
                ]
            )
        ]
    }

    // The number the call in a row's result carries.
    private func called(in implementation: Linked.Implementation) throws -> Int {
        guard
            case let .body(body, _) = implementation,
            case let .call(call)? = body.result
        else {
            throw LinkError("'b.asks' holds no call", at: nil)
        }

        return call.procedure
    }

    // Two documents, the second calling a word the first declares.
    private func calling() throws -> [Module] {
        [
            try Module(
                procedures: [
                    "a.aaa": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(0))),
                    "a.answers": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                ]
            ),
            try Module(
                procedures: [
                    entryName: Procedure(body: [], result: .call(Call(selector: "b.asks"))),
                    "b.asks": Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "a.answers"))
                    )
                ]
            )
        ]
    }
}
