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

// What a reading of an object refuses.
//
// An object is this runtime's own writing, so what is asked here is what
// happens when the bytes are not that. Each case bends one field of a real
// object, because a writing built by hand would prove only that the reading
// refuses something it was never handed.
@Suite("An object whose writing is not one")
struct ObjectReadingTests {
    // MARK: - Property
    // A stand-in for what a caller works out from the bytes, which this
    // package does not write. What these ask is what a reading refuses, so any
    // answer stands as long as an object compiled against another one can be
    // written down at all.
    private let builder = Builder { value in Fingerprint(Array("\(value)".utf8)) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a count is written below zero")
    func aCountBelowZero() async throws {
        // Given. A real object whose frame counts its slots below zero.
        var parts = try await parts()

        guard case var .array(table) = parts["rows"],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(frame) = implementation[2]
        else {
            Issue.record("an object writes a row's frame beside its body")

            return
        }

        frame[0] = .int(-1)
        implementation[2] = .array(frame)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a name keys two entries")
    func aNameWrittenTwice() async throws {
        // Given. A real object whose declared types list repeats one entry.
        var parts = try await parts()

        guard case let .array(types) = parts["types"],
              let first = types.first
        else {
            Issue.record("an object is written as its parts under their keys")

            return
        }

        parts = parts.writing("types", with: .array(types + [first]))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a part is missing")
    func aPartMissing() async throws {
        // Given. A real object with one of its parts taken off.
        let parts = try await parts()

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts.removing("constants")), of: nil)
        }
    }

    @Test("is refused where a part this reads none of is written")
    func aPartUnknown() async throws {
        let parts = try await parts()

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts.writing("extra", with: .null)), of: nil)
        }
    }

    @Test("is refused where it is a document")
    func aDocument() async throws {
        // Given. A record that says `warp` where an object says `object`. What
        // tells the two apart at the door is what each says it is.
        let parts = try await parts()

        // When / Then. Refused as a document, by its own name.
        #expect {
            try Compiled(written: .dictionary(parts.removing(ObjectLayout.formatKey).writing(Module.versionKey, with: .int(1))), of: nil)
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

        guard case var .array(numbering) = parts["typeNumbering"],
              case let .array(types) = numbering[0],
              let first = types.first
        else {
            Issue.record("an object writes its type numbering as a part")

            return
        }

        numbering[0] = .array(types + [first])
        parts = parts.writing("typeNumbering", with: .array(numbering))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a body stands past its frame")
    func aBodyPastItsFrame() async throws {
        // Given. A row whose body binds a local and reads it back, so the slot
        // it stands on is its own rather than a parameter's, and a frame shrunk
        // to hold none of it.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(binding: .constant("n"), expression: .literal(.int(1)))],
                    result: reference("n")
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(table) = parts["rows"],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(frame) = implementation[2],
              case let .int(size) = frame[0], size > 0,
              case let .array(parameters) = frame[1], parameters.isEmpty
        else {
            Issue.record("a row with a local stands on a slot no parameter holds")

            return
        }

        frame[0] = .int(0)
        implementation[2] = .array(frame)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where the format it is laid out as is not this one")
    func aFormatThisDoesNotRead() async throws {
        // Given. A real object saying a format this does not lay out.
        let parts = try await parts()

        // When / Then. The parts behind the number are laid out by it, so what
        // refuses is the number and nothing further in.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts.writing(ObjectLayout.formatKey, with: .int(ObjectLayout.format + 1))), of: nil)
        }
    }

    @Test("is refused where a layout's names are not in order")
    func aLayoutOutOfOrder() async throws {
        // Given. A declaration that writes no `returns`, so what the build read
        // off its body stands in the object as a lowered record, layout and
        // types apart.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    body: [],
                    result: .record(["a": .literal(.int(1)), "b": .literal(.string("s"))])
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(answers) = parts["answers"],
              case var .array(entry) = answers[0],
              case var .array(answer) = entry[1],
              case var .array(record) = answer[1],
              case var .array(layout) = record[0],
              case let .array(names) = layout[1],
              names.count > 1
        else {
            Issue.record("a declaration that wrote no answer stands one as a lowered record")

            return
        }

        // The names swapped and the types left where they were. A reading that
        // put the names back in order would pair each with the other's type.
        layout[1] = .array(names.reversed())
        record[0] = .array(layout)
        answer[1] = .array(record)
        entry[1] = .array(answer)
        answers[0] = .array(entry)
        parts = parts.writing("answers", with: .array(answers))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a frame names fewer slots than it holds")
    func aFrameNamingTooFew() async throws {
        var parts = try await parts()

        guard case var .array(table) = parts["rows"],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(frame) = implementation[2],
              case let .array(names) = frame[4],
              !names.isEmpty
        else {
            Issue.record("an object writes a row's frame beside its body")

            return
        }

        frame[4] = .array(names.dropLast())
        implementation[2] = .array(frame)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a call stands more arguments than its callee takes")
    func aCallStandingTooMany() async throws {
        // Given. A document whose body calls one of its own declarations, with
        // one argument added to what the call stands. The row it reaches is the
        // link's answer, so the link is where this is asked.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "app.twice", arguments: ["n": .literal(.int(2))]))
                ),
                "app.twice": Procedure(
                    signature: Signature(parameters: ["n": Parameter(type: .int)], returns: .int),
                    body: [],
                    result: reference("n")
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(table) = parts["rows"],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case var .array(call) = operation[1],
              case let .array(arguments) = call[2]
        else {
            Issue.record("an object writes a body whose result is a call")

            return
        }

        call[2] = .array(arguments + [.array([])])
        operation[1] = .array(call)
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then. The row the call reaches is this document's own, so the
        // reading answers it and no link is needed.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
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

        row[0] = .string("app.entr\u{0079}\u{0301}")
        declared[0] = .array(row)
        parts = parts.writing("rows", with: .array(declared))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a name keys a list out of order")
    func keysOutOfOrder() async throws {
        // Given. A real object whose declared types stand in some other
        // order. The values read alike either way, so what breaks is quieter:
        // one object would have two writings and a cache key two answers.
        let sut = try Module(
            types: ["app.One": .record(["x": .int]), "app.Two": .record(["y": .int])],
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case let .array(types) = parts["types"],
              types.count == 2
        else {
            Issue.record("an object writes its declared types in name order")

            return
        }

        parts = parts.writing("types", with: .array(types.reversed()))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a loop keeps a run its frame does not hold")
    func aRunPastTheFrame() async throws {
        // Given. A body whose loop keeps a run of its slots, with the run moved
        // out past the frame and left empty. An empty run names no slot and a
        // run read as one is read whole, so the bounds are what a frame has to
        // hold either way.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .nullable(.int)),
                    body: [],
                    result: .loop(
                        while: .call(Call(
                            receiver: reference("round", "index"),
                            selector: "std.math.lessThan",
                            arguments: ["value": .literal(.int(2))]
                        )),
                        body: Block(
                            body: [Statement(binding: .constant("k"), expression: reference("round", "index"))],
                            result: reference("k")
                        ),
                        round: "round"
                    )
                )
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(table) = parts["rows"],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case let .int(9) = operation[0],
              case let .array(keeps) = operation[4],
              keeps.count == 1
        else {
            Issue.record("an object writes a loop that keeps a run of its slots")

            return
        }

        operation[4] = .array([.array([.int(9999), .int(9999)])])
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts = parts.writing("rows", with: .array(table))

        // When / Then. Refused, rather than reaching the run that reads it.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a claim's contracts stand out of order")
    func claimsOutOfOrder() async throws {
        // Given. A type that answers two contracts, with the two swapped. The
        // set reads the same either way, so what breaks is quieter: one
        // object would have two writings.
        let sut = try Module(
            types: ["app.Box": .record(["v": .int])],
            contracts: [
                "app.One": ["one": Signature(returns: .int)],
                "app.Two": ["two": Signature(returns: .int)]
            ],
            claims: ["app.Box": ["app.One", "app.Two"]],
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.Box.one": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("app.Box"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "app.Box.two": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("app.Box"))],
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

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a numbering's closure table stands out of order")
    func numberingClosuresOutOfOrder() async throws {
        // Given. A document whose two declarations each write a closure, with
        // the table that says where each one's begin written backwards.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))))
                    )],
                    result: .apply(reference("made"), arguments: [:])
                ),
                "app.other": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))))
                    )],
                    result: .apply(reference("made"), arguments: [:])
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

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a numbering's imports stand out of order")
    func numberingImportsOutOfOrder() async throws {
        // Given. A document that sends two procedures, with the two swapped in
        // the numbering. What a name stands at is read off this list, so a name
        // written twice or out of place rewires a call rather than refusing it.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(
                        receiver: .call(Call(
                            receiver: .literal(.int(1)),
                            selector: "std.math.plus",
                            arguments: ["value": .literal(.int(2))]
                        )),
                        selector: "std.math.minus",
                        arguments: ["value": .literal(.int(3))]
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

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a value settles a procedure into it")
    func aValueHoldingAProcedure() async throws {
        // Given. A real object with a module variable standing a value no
        // writing of one could lay down. The writing refuses it, so a reading
        // that took it would hold what it could never write out again.
        let holding = try Module(
            variables: [
                "app.later": .closure(
                    Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(7)))
                )
            ],
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )
        let settled = try await builder.compile([holding] + Module.standard)
            .flatMap(\.variables)
            .first { entry in entry.value.holdsProcedure }

        var parts = try await parts()

        guard let settled else {
            Issue.record("a module variable that starts as a closure settles one into a value")

            return
        }

        parts = parts.writing("variables", with: .array([.array([.string(settled.name.spelling), settled.value])]))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where the numbers behind the spellings run past what an int holds")
    func closureNumbersPastAnInt() async throws {
        // Given. Two declarations whose counts add up to exactly what an int
        // holds. The sum stands, and the number the second closure takes is
        // that sum counted from behind the spellings, which does not.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [:])
                ),
                "app.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array([
            .array([.string("app.entry"), .int(.max - 1)]),
            .array([.string("app.other"), .int(1)])
        ])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where a numbering counts more closures than the table carries rows")
    func moreClosuresThanRows() async throws {
        // Given. One declaration writing one closure, with the count raised.
        // The table behind the declarations is where the closures stand, so a
        // count above it numbers closures no row holds.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [:])
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

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where the closure counts add up past what an int holds")
    func closureCountsPastAnInt() async throws {
        // Given. Two declarations, each counted for as many closures as an int
        // holds. Neither count is a number on its own, and their sum is the
        // one a numbering would have to count out.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [:])
                ),
                "app.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        var parts = try await parts(of: sut)

        guard case var .array(numbering) = parts["numbering"]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[1] = .array([
            .array([.string("app.entry"), .int(.max)]),
            .array([.string("app.other"), .int(.max)])
        ])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where it stands against a document other than the one it was kept under")
    func anObjectOfAnotherDocument() async throws {
        // Given. A document with an identity, and its object.
        let sut = try Module(
            try Module(
                procedures: [
                    "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                ]
            ).draft,
            identity: Identity([0x01, 0x02, 0x03])
        )
        let compiled = try await builder.compile([sut] + Module.standard)

        guard let mine = compiled.first(where: { one in one.identity != nil }),
              let written = mine.written
        else {
            Issue.record("a document with an identity compiles to an object standing against it")

            return
        }

        // When / Then. Read under the identity it stands against, and refused
        // under any other: what an object says about which document it is,
        // is the one thing about it nothing else can check.
        #expect(throws: Never.self) {
            try Compiled(written: written, of: Identity([0x01, 0x02, 0x03]))
        }

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: written, of: Identity([0x09]))
        }

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: written, of: nil)
        }
    }

    @Test("is refused where what it leaned on stands out of order")
    func dependenciesOutOfOrder() async throws {
        // Given. A real object whose two dependencies are written the other
        // way round. Both name the same pair, so a reading that took either
        // order would let two writings say one object.
        let parts = try await parts().writing("dependencies", with: .array([.bytes([0x02]), .bytes([0x01])]))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    @Test("is refused where it leans on one object twice")
    func dependenciesRepeated() async throws {
        // Given. A real object naming one of them twice. What it leaned on is
        // a set, and a set written down twice is a writing no set makes.
        let parts = try await parts().writing("dependencies", with: .array([.bytes([0x01]), .bytes([0x01])]))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    // MARK: - Public
    @Test("is refused where a numbering counts a declaration for no closures")
    func aDeclarationCountedForNone() async throws {
        // Given. One declaration writing one closure, with a second name
        // counted for none beside it. A writing counts a name only where that
        // name wrote one, so nothing it lays down carries this entry.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("made"),
                        expression: .closure(
                            Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                        )
                    )],
                    result: .apply(reference("made"), arguments: [:])
                ),
                "app.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
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

        numbering[1] = .array(counts + [.array([.string("app.other"), .int(0)])])
        parts = parts.writing("numbering", with: .array(numbering))

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .dictionary(parts), of: nil)
        }
    }

    // MARK: - Private
    // The object as written, its parts under their keys, so a test bends
    // what it means to bend.
    private func parts() async throws -> Value.Dictionary {
        try await parts(of: try Module(
            types: ["app.Point": .record(["x": .int, "y": .int])],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(parameters: ["p": Parameter(type: .any)], returns: .named("app.Point")),
                    body: [],
                    result: .cast(reference("p"), as: .named("app.Point"), optional: false)
                )
            ]
        ))
    }

    private func parts(of module: Module) async throws -> Value.Dictionary {
        let compiled = try await builder.compile([module] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("app.entry") }),
              case let .dictionary(written) = mine.written
        else {
            throw ObjectMissing()
        }

        return written
    }
}

private struct ObjectMissing: Error { }
