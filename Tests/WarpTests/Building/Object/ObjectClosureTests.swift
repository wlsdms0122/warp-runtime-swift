//
//  ObjectClosureTests.swift
//  WarpTests
//
//  Created by JSilver on 9/18/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A closure a fold settled into a value, written down and read back. An
// object spells it by the declaration that wrote it and which of that
// declaration's it is, and the link reading the object answers the row: the
// row the fold had is the fold's link's, and no object holds one.
@Suite("An object a procedure settled into")
struct ObjectClosureTests {
    // MARK: - Property
    private let builder = Builder(fingerprinting: Fingerprint.of)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a module variable starting as a closure comes back and runs")
    func aVariableThatStartsAsAProcedure() async throws {
        // Given
        let sut = try answeringLater(7, identity: Identity([1]))

        // When
        let answer = try await roundTripped(sut, entry: "app.entry")

        // Then
        #expect(answer == .int(7))
    }

    @Test("a literal a body folded from a closure comes back and runs")
    func aLiteralFoldedFromAProcedure() async throws {
        // Given
        let sut = try madeOf(5, entry: "app.entry", identity: Identity([1]))

        // When
        let answer = try await roundTripped(sut, entry: "app.entry")

        // Then
        #expect(answer == .int(5))
    }

    @Test("a closure folded out of another document's procedure comes back and runs")
    func aClosureFoldedAcrossDocuments() async throws {
        // Given. The closure captures a name by copy, so what it holds
        // travels with it
        let maker = try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [Statement(binding: .constant("x"), expression: .literal(.int(11)))],
                    result: .closure(Procedure(signature: Signature(returns: .int), body: [], result: reference("x")))
                )
            ],
            identity: Identity([1])
        )
        let sut = try Module(
            imports: ["app.make"],
            variables: ["app.held": .call(Call(selector: "app.make"))],
            procedures: [
                "app.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.held"), arguments: [])
                )
            ],
            identity: Identity([2])
        )

        // When
        let answer = try await roundTripped(sut, beside: [maker], entry: "app.entry")

        // Then
        #expect(answer == .int(11))
    }

    @Test("a closure spelled by a writer no document of the link has is refused at the link")
    func aClosureOfAnUnknownWriterIsRefused() async throws {
        // Given. A compiled document whose variable starts as a closure some
        // other spelling claims to have written.
        let compiled = try await builder.compile(Module.standard + [answeringLater(7)])
        let forged = try holding(Closure(writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("app.nobody")), nth: 0, linked: nil, captured: []), in: compiled)

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.link(forged, supplying: Supplying(Module.standard))
        }
    }

    @Test("a closure spelled past what its writer wrote is refused at the link")
    func aClosurePastItsWriterIsRefused() async throws {
        // Given. The writer wrote one closure, and the value asks for its sixth
        let compiled = try await builder.compile(Module.standard + [answeringLater(7)])
        let forged = try holding(Closure(writer: Closure.Writer(document: try #require(compiled.last?.naming), declaration: .binding("app.later")), nth: 5, linked: nil, captured: []), in: compiled)

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.link(forged, supplying: Supplying(Module.standard))
        }
    }

    @Test("two documents may each write a closure under one constant's spelling, and each runs its own")
    func twoDocumentsMayShareAConstantsSpelling() async throws {
        // Given. Two documents that were written down, compiled apart, each
        // with a constant of one spelling holding a closure of its own. A
        // constant's spelling is its document's, so the two are two writers.
        let one = try await builder.compile(Module.standard + [madeOf(5, entry: "app.one", identity: Identity([1]))])
        let other = try await builder.compile(
            [madeOf(6, entry: "app.two", identity: Identity([2]))],
            against: try builder.lay(one, supplying: Supplying(Module.standard))
        )
        let read = try (one + other).map { document in
            try Compiled(written: try #require(document.written), of: document.identity, fingerprint: document.fingerprint)
        }

        // When
        let image = try await builder.link(read, supplying: Supplying(Module.standard))

        // Then
        #expect(try await Executor().run(image, entry: "app.two") == .int(6))
    }

    @Test("a closure an unwritten document folded out of another unwritten one runs the other's body")
    func aClosureFoldedBetweenUnwrittenDocumentsKeepsItsWriter() async throws {
        // Given. Two documents nobody wrote down, both writing a closure under
        // `app.made`. The second hands its own out through a procedure, and
        // the first folds that into a variable. The compile of each names it,
        // so the first document's own `app.made` is not the one it holds.
        let other = try Module(
            constants: ["app.made": .closure(answering(6))],
            procedures: [
                "app.give": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [],
                    result: reference("app.made")
                )
            ]
        )
        let one = try Module(
            imports: ["app.give"],
            constants: ["app.made": .closure(answering(5))],
            variables: ["app.held": .call(Call(selector: "app.give"))],
            procedures: [
                "app.one": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .apply(reference("app.held"), arguments: []))
            ]
        )

        // When
        let image = try await builder.build(Module.standard + [other, one])

        // Then
        #expect(try await Executor().run(image, entry: "app.one") == .int(6))
    }

    @Test("two documents nobody wrote down each read a closure of their own under one name")
    func twoUnwrittenWritersOfOneNameEachReadTheirOwn() async throws {
        // Given. The same two, with no text to tell them apart by, told apart
        // by their compiles
        let one = try await builder.compile(Module.standard + [madeOf(5, entry: "app.one")])
        let other = try await builder.compile([madeOf(6, entry: "app.two")], against: try builder.lay(one, supplying: Supplying(Module.standard)))

        // When
        let image = try await builder.link(one + other, supplying: Supplying(Module.standard))

        // Then
        #expect(try await Executor().run(image, entry: "app.two") == .int(6))
    }

    @Test("a closure folded in one compile is answered anew where its document is laid into another")
    func aClosureFoldedEarlierIsAnsweredWhereLaid() async throws {
        // Given. A document compiled in memory, whose constant closure calls
        // a procedure of the vocabulary, so its body reaches another row.
        // Laid down again in another order, the rows stand elsewhere.
        let calling = try Module(
            imports: ["std.math.plus"],
            constants: [
                "app.made": .closure(
                    Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "std.math.plus", arguments: [.literal(.int(2)), .literal(.int(3))]))
                    )
                )
            ],
            procedures: [
                "app.give": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [],
                    result: reference("app.made")
                )
            ]
        )
        let compiled = try await builder.compile(Module.standard + [calling])
        let reordered = compiled.reversed().map { document in document }
        let folding = try Module(
            imports: ["app.give"],
            constants: ["app.got": .call(Call(selector: "app.give"))],
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .apply(reference("app.got"), arguments: []))]
        )

        // When
        let laid = try builder.lay(reordered, supplying: Supplying(Module.standard))
        let against = try await builder.compile([folding], against: laid)
        let image = try await builder.link(reordered + against, supplying: Supplying(Module.standard))

        // Then
        #expect(try await Executor().run(image, entry: "app.entry") == .int(5))
    }

    @Test("an object laid beside another compile of what it leaned on is refused")
    func anObjectBesideAnotherCompileOfItsDependencyIsRefused() async throws {
        // Given. A document compiled against another, and that other compiled
        // again with a change. The first says what it leaned on by
        // fingerprint, and that fingerprint is not among what is laid now.
        let first = try await builder.compile(Module.standard + [madeOf(5, entry: "app.one", identity: Identity([1]))])
        let leaning = try Module(
            imports: ["app.one"],
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .call(Call(selector: "app.one")))],
            identity: Identity([2])
        )
        let second = try await builder.compile([leaning], against: try builder.lay(first, supplying: Supplying(Module.standard)))
        let changed = try await builder.compile(Module.standard + [madeOf(6, entry: "app.one", identity: Identity([1]))])

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.link(changed + second, supplying: Supplying(Module.standard))
        }
        #expect(throws: BuildError.self) {
            try builder.lay(changed + second, supplying: Supplying(Module.standard))
        }
    }

    @Test("a fold through a document read out of an object hands on the closure the object holds")
    func aFoldThroughAReadObjectHandsOnItsClosure() async throws {
        // Given. A written document whose constant holds a closure and whose
        // procedure hands it on, compiled, written down and read back. A
        // second document folds a constant through that procedure, and its
        // entry applies what it got.
        let held = try Module(
            constants: ["app.made": .closure(answering(5))],
            procedures: [
                "app.give": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [],
                    result: reference("app.made")
                )
            ],
            identity: Identity([1])
        )
        let read = try (await builder.compile(Module.standard + [held])).map { document in
            try Compiled(written: try document.object(), of: document.identity, fingerprint: document.fingerprint)
        }
        let folding = try Module(
            imports: ["app.give"],
            constants: ["app.got": .call(Call(selector: "app.give"))],
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .apply(reference("app.got"), arguments: []))],
            identity: Identity([2])
        )

        // When. The second document is written down and read back too, so
        // what its constant settled to crosses an object as well.
        let compiled = try (await builder.compile([folding], against: try builder.lay(read, supplying: Supplying(Module.standard)))).map { document in
            try Compiled(written: try document.object(), of: document.identity, fingerprint: document.fingerprint)
        }
        let image = try await builder.link(read + compiled, supplying: Supplying(Module.standard))

        // Then
        #expect(try await Executor().run(image, entry: "app.entry") == .int(5))
    }

    @Test("a closure holding fewer cells than its frame is filled from is refused at the link")
    func aClosureHoldingTooFewCellsIsRefused() async throws {
        // Given. The closure the writer wrote takes one cell with it, and the
        // value claims none
        let compiled = try await builder.compile(Module.standard + [capturingMaker(identity: Identity([1])), holdingUser(identity: Identity([2]))])
        let forged = try holding(
            Closure(writer: Closure.Writer(document: .written(Identity([1])), declaration: .procedure("app.make")), nth: 0, linked: nil, captured: []),
            in: compiled
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.link(forged, supplying: Supplying(Module.standard))
        }
    }

    @Test("a closure a document nobody wrote down wrote is not written into an object")
    func aClosureOfAnUnwrittenDocumentIsNotWritten() async throws {
        // Given. A written document whose variable folds a closure out of
        // an unwritten one. An object cannot spell the writer, so none is
        // written for the holder
        let maker = try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [],
                    result: .closure(answering(3))
                )
            ]
        )
        let sut = try Module(
            imports: ["app.make"],
            variables: ["app.held": .call(Call(selector: "app.make"))],
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .apply(reference("app.held"), arguments: []))],
            identity: Identity([7])
        )

        // When
        let compiled = try await builder.compile(Module.standard + [maker, sut])

        // Then
        #expect(compiled.last?.written == nil)
    }

    @Test("a closure holding a cell its frame has not is refused at the link")
    func aClosureHoldingACellPastItsFrameIsRefused() async throws {
        // Given. The closure the writer wrote takes nothing with it, and the
        // value claims a cell at 99
        let compiled = try await builder.compile(Module.standard + [answeringLater(7)])
        let forged = try holding(
            Closure(
                writer: Closure.Writer(document: try #require(compiled.last?.naming), declaration: .binding("app.later")),
                nth: 0,
                linked: nil,
                captured: [(slot: 99, cell: .value(.int(1)))]
            ),
            in: compiled
        )

        // When / Then. Refused where a link answers it, and where a compile
        // lays a body holding it down to fold through
        await #expect(throws: BuildError.self) {
            try await builder.link(forged, supplying: Supplying(Module.standard))
        }

        let inBody = try holdingInBody(
            Closure(
                writer: Closure.Writer(document: try #require(compiled.last?.naming), declaration: .binding("app.later")),
                nth: 0,
                linked: nil,
                captured: [(slot: 99, cell: .value(.int(1)))]
            ),
            in: compiled
        )

        #expect(throws: BuildError.self) {
            try builder.lay(inBody, supplying: Supplying(Module.standard))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The same objects, with the entry's body applying the closure handed in
    // as a literal it holds.
    private func holdingInBody(_ closure: Closure, in compiled: [Compiled]) throws -> [Compiled] {
        try compiled.map { one in
            guard let entry = one.declared.firstIndex(of: "app.entry"),
                  case let .body(_, frame) = one.table[entry].implementation
            else {
                return one
            }

            var table = one.table
            let row = table[entry]

            table[entry] = try Judged(
                label: row.label,
                signature: row.signature,
                access: row.access,
                constness: row.constness,
                isolation: row.isolation,
                failing: row.failing,
                sends: row.sends,
                judging: .body(
                    LoweredBody(instructions: [], result: .apply(.literal(.procedure(closure)), arguments: [])),
                    frame
                )
            )

            return try Compiled(
                document: one.document,
                types: one.types,
                constraints: one.constraints,
                contracts: one.contracts,
                claims: one.claims,
                leaned: one.leaned,
                declared: one.declared,
                constants: one.constants,
                table: table,
                answers: one.answers,
                numbering: one.numbering,
                typeNumbering: one.typeNumbering,
                judging: one.variables,
                dependencies: one.dependencies
            )
        }
    }

    private func answeringLater(_ number: Int, identity: Identity? = nil) throws -> Module {
        try Module(
            variables: ["app.later": .closure(answering(number))],
            procedures: [
                "app.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.later"), arguments: [])
                )
            ],
            identity: identity
        )
    }

    private func capturingMaker(identity: Identity? = nil) throws -> Module {
        try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [Statement(binding: .constant("x"), expression: .literal(.int(11)))],
                    result: .closure(Procedure(signature: Signature(returns: .int), body: [], result: reference("x")))
                )
            ],
            identity: identity
        )
    }

    private func holdingUser(identity: Identity? = nil) throws -> Module {
        try Module(
            imports: ["app.make"],
            variables: ["app.held": .call(Call(selector: "app.make"))],
            procedures: [
                "app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .apply(reference("app.held"), arguments: []))
            ],
            identity: identity
        )
    }

    private func madeOf(_ number: Int, entry: Name, identity: Identity? = nil) throws -> Module {
        try Module(
            constants: ["app.made": .closure(answering(number))],
            procedures: [
                entry: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.made"), arguments: [])
                )
            ],
            identity: identity
        )
    }

    // The same objects, with the one variable there is starting as the
    // closure handed in.
    private func holding(_ closure: Closure, in compiled: [Compiled]) throws -> [Compiled] {
        try compiled.map { one in
            guard let held = one.variables.first else { return one }

            return try Compiled(
                document: one.document,
                types: one.types,
                constraints: one.constraints,
                contracts: one.contracts,
                claims: one.claims,
                leaned: one.leaned,
                declared: one.declared,
                constants: one.constants,
                table: one.table,
                answers: one.answers,
                numbering: one.numbering,
                typeNumbering: one.typeNumbering,
                judging: [(name: held.name, value: .procedure(closure))],
                dependencies: one.dependencies
            )
        }
    }

    private func answering(_ number: Int) -> Procedure {
        Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(number)))
    }

    // The module compiled beside the vocabulary and the documents it leans
    // on, every object written to bytes and read back, and the run's answer.
    private func roundTripped(_ module: Module, beside others: [Module] = [], entry: Name) async throws -> Value? {
        let compiled = try await builder.compile(Module.standard + others + [module])
        let read = try compiled.map { one -> Compiled in
            let written = try #require(one.written, "an object is written for \(one.document.spelled(at: 0))")

            return try Compiled(written: written, of: one.document.identity, fingerprint: one.fingerprint)
        }
        let image = try await builder.link(read, supplying: Supplying(Module.standard))

        return try await Executor().run(image, entry: entry)
    }
}
