//
//  ObjectReadingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What a reading of an object refuses.
//
// An object is this runtime's own writing, so what is asked here is what
// happens when the bytes are not that. Each test mutates one field of a real
// object, because a writing built by hand would prove only that the reading
// refuses something it was never handed.
@Suite("An object whose writing is not one")
struct ObjectReadingTests {
    private struct ObjectMissing: Error {
    }

    // Doubling by sending the procedure that multiplies.
    private struct TwiceQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        enum Imports: Int, ImportSet {
            case times

            // MARK: - Property
            var selector: Name { "Int.times" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.times, handing: [question[.of], .int(2)])
        }

        // MARK: - Private
    }

    // MARK: - Property
    // A stand-in for what a host works out from the bytes, which this
    // package does not write. What these ask is what a reading refuses, so any
    // answer stands as long as an object compiled against another one can be
    // written down at all.
    private let builder = Builder { value in Fingerprint(Array("\(value)".utf8)) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a native sends a spelling its numbering gives no number")
    func aSendItsNumberingDoesNotNumber() async throws {
        // Given / When. A real object whose native row sends a spelling other
        // than the one its document numbered
        let refusal = try await reading { send in send[1] = .string("Standard.Numeric.minus") }

        // Then. Refused where the object is read, before any link
        #expect(refusal?.message.contains("'App.entry' sends 'Standard.Numeric.minus', which its document numbers nowhere") == true)
    }

    @Test("is refused where a native's sends stand apart")
    func sendsStandingApart() async throws {
        // Given / When. A real object whose native row's one send stands at
        // the second place
        let refusal = try await reading { send in send[0] = .int(1) }

        // Then. Refused where the object is read, before any link
        #expect(refusal?.message.contains("'App.entry' sends procedures standing at [1]") == true)
    }

    @Test("is refused where a count is written below zero")
    func aCountBelowZero() async throws {
        // Given. A real object whose frame counts its slots below zero.
        var parts = try await parts()

        guard case var .array(table) = parts["rows"],
            case var .array(row) = table[0],
            case var .array(implementation) = row[3],
            case var .array(frame) = implementation[2]
        else {
            Issue.record("an object writes a row's frame beside its body")

            return
        }

        frame[0] = .int(-1)
        implementation[2] = .array(frame)
        row[3] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'frame' writes -1 where a count stands")
        }
    }

    @Test("is refused where a name keys two entries")
    func aNameWrittenTwice() async throws {
        // Given. A real object whose declared types list one name twice, each
        // entry holding the type it was written with.
        let sut = try Module(
            types: ["App.One": .struct(["x": .int]), "App.Two": .struct(["y": .int])],
            procedures: [
                "App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case let .array(types) = parts["types"],
            types.count == 2,
            case let .array(first) = types[0],
            case let .array(second) = types[1]
        else {
            Issue.record("an object is written as its parts under their keys")

            return
        }

        parts = parts.writing("types", with: .array([types[0], .array([first[0], second[1]])]))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'types' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a part is missing")
    func aPartMissing() async throws {
        // Given. A real object with one of its parts taken off.
        let parts = try await parts()

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts.removing("constants")), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'object' writes no 'constants'")
        }
    }

    @Test("is refused where a part this reads none of is written")
    func aPartUnknown() async throws {
        // Given
        let parts = try await parts()

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts.writing("extra", with: .null)), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'object' writes 'extra', which this reads none of")
        }
    }

    @Test("is refused where it is a document")
    func aDocument() async throws {
        // Given. A struct that says `warp` where an object says `object`. What
        // tells the two apart at the door is what each says it is.
        let parts = try await parts()

        // When / Then. Refused as a document, by its own name.
        #expect {
            try Compiled(written: .dictionary(parts.removing(ObjectLayout.Key.object.name).writing(Module.versionKey, with: .int(1))), of: nil)
        } throws: { error in
            "\(error)".contains("this is a document, and not an object")
        }
    }

    @Test("is refused where a numbering names one type twice")
    func aNumberingThatRepeats() async throws {
        // Given. A real object whose type numbering lists one name twice. The
        // numbering answers by position, so a swallowed name moves every number
        // after it onto some other declaration.
        var parts = try await parts()

        guard case let .array(types) = parts["typeNumbering"], let first = types.first else {
            Issue.record("an object writes its type numbering as a part")

            return
        }

        parts = parts.writing("typeNumbering", with: .array(types + [first]))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'type numbering' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a body stands past its frame")
    func aBodyPastItsFrame() async throws {
        // Given. A row whose body binds a local and reads it back, so the slot
        // it stands on is its own rather than a parameter's, and a frame shrunk
        // to hold none of it.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(binding: .constant("n"), expression: .literal(.int(1)))],
                    result: reference("n")
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(table) = parts["rows"],
            case var .array(row) = table[0],
            case var .array(implementation) = row[3],
            case var .array(frame) = implementation[2],
            case let .int(size) = frame[0], size > 0,
            case let .array(parameters) = frame[1], parameters.isEmpty
        else {
            Issue.record("a row with a local stands on a slot no parameter holds")

            return
        }

        frame[0] = .int(0)
        frame[4] = .array([])
        implementation[2] = .array(frame)
        row[3] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a body stands on a slot its frame of 0 does not hold")
        }
    }

    @Test("is refused where the format it is laid out as is not this one")
    func aFormatThisDoesNotRead() async throws {
        // Given. A real object saying a format this does not lay out.
        let parts = try await parts()

        // When / Then. The parts behind the number are laid out by it, so what
        // refuses is the number and nothing further in.
        #expect {
            try Compiled(written: .dictionary(parts.writing(ObjectLayout.Key.object.name, with: .int(ObjectLayout.format + 1))), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("the object is laid out as format 2, and this reads format 1")
        }
    }

    @Test("is refused where a layout's names are not in order")
    func aLayoutOutOfOrder() async throws {
        // Given. A body answering a struct literal, which the object writes as
        // the struct's layout beside the code filling each field.
        let sut = try Module(
            types: ["App.Pair": .struct(["a": .int, "b": .string])],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .named("App.Pair")),
                    body: [],
                    result: .struct(["a": .literal(.int(1)), "b": .literal(.string("s"))])
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard let number = result(of: parts),
            case var .array(operations) = parts["operationTable"],
            case var .array(operation) = operations[number],
            case var .array(built) = operation[1],
            case var .array(layout) = built[0],
            case let .array(names) = layout[1],
            names.count > 1
        else {
            Issue.record("an object writes a struct literal as its layout and its fields")

            return
        }

        // The names swapped and the fields left where they were. A reading that
        // put the names back in order would pair each with the other's code.
        layout[1] = .array(names.reversed())
        built[0] = .array(layout)
        operation[1] = .array(built)
        operations[number] = .array(operation)
        parts = parts.writing("operationTable", with: .array(operations))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a layout's fields are not in name order")
        }
    }

    @Test("is refused where a frame names fewer slots than it holds")
    func aFrameNamingTooFew() async throws {
        // Given
        var parts = try await parts()

        // When / Then
        guard case var .array(table) = parts["rows"],
            case var .array(row) = table[0],
            case var .array(implementation) = row[3],
            case var .array(frame) = implementation[2],
            case let .array(names) = frame[4],
            !names.isEmpty
        else {
            Issue.record("an object writes a row's frame beside its body")

            return
        }

        frame[4] = .array(names.dropLast())
        implementation[2] = .array(frame)
        row[3] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a frame of 1 names 0 slot(s)")
        }
    }

    @Test("is refused where a name is not in normal form")
    func aNameNotInNormalForm() async throws {
        // Given. A real object whose declared spelling is written in the
        // decomposed form. It reads alike and compares apart, so every order
        // and every lookup built on it would go quiet.
        var parts = try await parts()

        guard case var .array(declared) = parts["rows"],
            case var .array(row) = declared.first
        else {
            Issue.record("an object writes its declared rows as a part")

            return
        }

        row[0] = .string("App.entr\u{0079}\u{0301}")
        declared[0] = .array(row)
        parts = parts.writing("rows", with: .array(declared))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("the name 'App.entrý' is not in normal form C")
        }
    }

    @Test("is refused where a name keys a list out of order")
    func keysOutOfOrder() async throws {
        // Given. A real object whose declared types stand in some other
        // order. The values read alike either way, so what breaks is quieter:
        // one object would have two writings and a cache key two answers.
        let sut = try Module(
            types: ["App.One": .struct(["x": .int]), "App.Two": .struct(["y": .int])],
            procedures: [
                "App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case let .array(types) = parts["types"],
            types.count == 2,
            case let .array(first) = types[0],
            case let .array(second) = types[1]
        else {
            Issue.record("an object writes its declared types in name order")

            return
        }

        // The names turned around, each entry holding the type it was
        // written with.
        parts = parts.writing("types", with: .array([.array([second[0], first[1]]), .array([first[0], second[1]])]))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'types' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a struct value's fields stand out of order")
    func aStructOutOfOrder() async throws {
        // Given. A real object whose body answers a constant holding a struct,
        // which the build folds to the struct value it is, its fields turned
        // around. A reading that sorted them would read two writings as one
        // object.
        let sut = try Module(
            types: ["App.Pair": .struct(["a": .int, "b": .int])],
            constants: [
                "pair": .cast(.struct(["a": .literal(.int(1)), "b": .literal(.int(2))]), as: .named("App.Pair"), optional: false)
            ],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .named("App.Pair")),
                    body: [],
                    result: reference("pair")
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard let number = result(of: parts),
            case let .array(operations) = parts["operationTable"],
            case let .array(literal) = operations[number],
            case let .int(held) = literal[1],
            case var .array(values) = parts["valueTable"],
            case var .array(value) = values[held],
            case let .array(names) = value[2],
            names.count == 2
        else {
            Issue.record("an object writes a struct literal as its names and values")

            return
        }

        // The names turned around, each value left where the writing put it,
        // since a value is read where it is held.
        value[2] = .array(names.reversed())
        values[held] = .array(value)
        parts = parts.writing("valueTable", with: .array(values))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("not in name order")
        }
    }

    @Test("is refused where a claim's contracts stand out of order")
    func claimsOutOfOrder() async throws {
        // Given. A type that answers two contracts, with the two swapped. The
        // set reads the same either way, so what breaks is quieter: one
        // object would have two writings.
        let sut = try Module(
            types: ["App.Box": .struct(["v": .int])],
            contracts: [
                "App.One": ["one": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)],
                "App.Two": ["two": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)]
            ],
            claims: ["App.Box": ["App.One", "App.Two"]],
            members: ["App.Box": ["one", "two"]],
            procedures: [
                "App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "App.Box.one": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("App.Box"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "App.Box.two": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("App.Box"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(2))
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(claims) = parts["claims"],
            case var .array(entry) = claims[0],
            case let .array(contracts) = entry[1],
            contracts.count == 2
        else {
            Issue.record("an object writes which contracts each type answers")

            return
        }

        entry[1] = .array(contracts.reversed())
        claims[0] = .array(entry)
        parts = parts.writing("claims", with: .array(claims))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'claims' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a numbering's closure table stands out of order")
    func numberingClosuresOutOfOrder() async throws {
        // Given. A document whose two declarations each write a closure, with
        // the table that says where each one's begin written backwards.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))))
                    )],
                    result: .apply(reference("made"), arguments: [])
                ),
                "App.other": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))))
                    )],
                    result: .apply(reference("made"), arguments: [])
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"],
            case let .array(closing) = numbering[1],
            closing.count == 2
        else {
            Issue.record("an object writes where each declaration's closures begin")

            return
        }

        numbering[1] = .array(closing.reversed())
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'numbering closures' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a numbering's imports stand out of order")
    func numberingImportsOutOfOrder() async throws {
        // Given. A document that sends two procedures, with the two swapped in
        // the numbering. What a name stands at is read off this list, so a name
        // written twice or out of place rewires a call rather than refusing it.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Numeric.minus",
                        arguments: [
                            .call(Call(
                                selector: "Standard.Numeric.plus",
                                arguments: [.literal(.int(1)), .literal(.int(2))]
                            )),
                            .literal(.int(3))
                        ]
                    ))
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"],
            case let .array(sent) = numbering[0],
            sent.count == 2
        else {
            Issue.record("an object writes what its document sends")

            return
        }

        numbering[0] = .array(sent.reversed())
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'numbering sends' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where the numbers behind the spellings run past what an Int holds")
    func closureNumbersPastAnInt() async throws {
        // Given. Two declarations whose counts add up to exactly what an int
        // holds. The sum stands, and the number the second closure takes is
        // that sum counted from behind the spellings, which does not.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [])
                ),
                "App.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array([
            .array([ObjectWriter.declaration(.procedure("App.entry")), .int(.max - 1)]),
            .array([ObjectWriter.declaration(.procedure("App.other")), .int(1)])
        ])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a numbering gives numbers past what an Int holds")
        }
    }

    @Test("is refused where a numbering counts more closures than the table carries rows")
    func moreClosuresThanRows() async throws {
        // Given. One declaration writing one closure, with the count raised.
        // The table behind the declarations is where the closures stand, so a
        // count above it numbers closures no row holds.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [])
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"],
            case let .array(counts) = numbering[1],
            case let .array(entry) = counts.first,
            counts.count == 1
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array([.array([entry[0], .int(4)])])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("an object numbers 4 closure(s) behind 1 row(s)")
        }
    }

    @Test("is refused where the closure counts add up past what an Int holds")
    func closureCountsPastAnInt() async throws {
        // Given. Two declarations, each counted for as many closures as an int
        // holds. Neither count is a number on its own, and their sum is the
        // one a numbering would have to count out.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [])
                ),
                "App.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array([
            .array([ObjectWriter.declaration(.procedure("App.entry")), .int(.max)]),
            .array([ObjectWriter.declaration(.procedure("App.other")), .int(.max)])
        ])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a numbering gives numbers past what an Int holds")
        }
    }

    @Test("is refused where it stands against a document other than the one it was kept under")
    func anObjectOfAnotherDocument() async throws {
        // Given. A document with an identity, and its object.
        let sut = try Module(
            try Module(
                procedures: [
                    "App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                ]
            ).draft,
            identity: Identity([0x01, 0x02, 0x03])
        )
        let compiled = try await builder.compile([sut] + Module.standard)

        let written = try #require(
            compiled.first(where: { one in one.identity != nil }),
            "a document with an identity compiles to an object standing against it"
        ).object()

        // When / Then. Read under the identity it stands against, and refused
        // under any other: what an object says about which document it is,
        // is the one thing about it nothing else can check.
        #expect(throws: Never.self) {
            try Compiled(written: written, of: Identity([0x01, 0x02, 0x03]))
        }

        #expect {
            try Compiled(written: written, of: Identity([0x09]))
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("this object stands against a document other than the one it was kept under")
        }

        #expect {
            try Compiled(written: written, of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("this object stands against a document other than the one it was kept under")
        }
    }

    @Test("is refused where what it leaned on stands out of order")
    func dependenciesOutOfOrder() async throws {
        // Given. A real object whose two dependencies are written the other
        // way round. Both name the same pair, so a reading that took either
        // order would let two writings say one object.
        let parts = try await parts().writing("dependencies", with: .array([.bytes([0x02]), .bytes([0x01])]))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'dependencies' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where it leans on one object twice")
    func dependenciesRepeated() async throws {
        // Given. A real object naming one of them twice. What it leaned on is
        // a set, and a set written down twice is a writing no set makes.
        let parts = try await parts().writing("dependencies", with: .array([.bytes([0x01]), .bytes([0x01])]))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused
                && "\(error)".contains("'dependencies' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where a numbering counts a declaration for no closures")
    func aDeclarationCountedForNone() async throws {
        // Given. One declaration writing one closure, with a second name
        // counted for none beside it. A writing counts a name only where that
        // name wrote one, so nothing it lays down carries this entry.
        let sut = try Module(
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [])
                ),
                "App.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"],
            case let .array(counts) = numbering[1],
            counts.count == 1
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array(counts + [.array([ObjectWriter.declaration(.procedure("App.other")), .int(0)])])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a numbering counts no closures for a name it counts")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A real object whose native row's first send is changed, and what it is
    // refused with where it is read.
    private func reading(_ change: (inout [Value]) -> Void) async throws -> ObjectRefused? {
        let sut = try Module(procedures: [
            "App.entry": Procedure(
                access: .public,
                signature: Signature(of: TwiceQuery.self, returns: .int),
                implementation: .query(TwiceQuery())
            )
        ])
        let compiled = try await builder.compile([sut] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("App.entry") }),
            case var .dictionary(parts) = try mine.object(),
            case var .array(table) = parts["rows"],
            case var .array(row) = table[0],
            case var .array(implementation) = row[3],
            case var .array(sending) = implementation[1],
            case var .array(send) = sending[0]
        else {
            Issue.record("an object writes a native's sends under its implementation")

            return nil
        }

        change(&send)
        sending[0] = .array(send)
        implementation[1] = .array(sending)
        row[3] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        return #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: mine.identity)
        }
    }

    // The number of the operation the first row's body answers with, which
    // stands in the operation table.
    private func result(of parts: Value.Dictionary) -> Int? {
        guard case let .array(rows) = parts["rows"],
            case let .array(row) = rows.first,
            case let .array(implementation) = row[3],
            case let .array(body) = implementation[1],
            case let .array(result) = body[1],
            case let .int(number) = result.first
        else {
            return nil
        }

        return number
    }

    // The object as written, its parts under their keys, so a test mutates
    // what it means to mutate.
    private func parts() async throws -> Value.Dictionary {
        try await parts(of: try Module(
            types: ["App.Point": .struct(["x": .int, "y": .int])],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "p", type: .any)],
                        returns: .named("App.Point"),
                        failing: .these(["cast_refused"])
                    ),
                    body: [],
                    result: .cast(reference("p"), as: .named("App.Point"), optional: false)
                )
            ]
        ))
    }

    private func parts(of module: Module) async throws -> Value.Dictionary {
        let compiled = try await builder.compile([module] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("App.entry") }),
            case let .dictionary(written) = try mine.object()
        else {
            throw ObjectMissing()
        }

        return written
    }
}
