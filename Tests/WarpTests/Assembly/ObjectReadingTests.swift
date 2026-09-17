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
        guard case var .array(parts) = try await parts(),
              case var .array(table) = parts[8],
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
        parts[8] = .array(table)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a name keys two entries")
    func aNameWrittenTwice() async throws {
        // Given. A real object whose declared types list repeats one entry.
        guard case var .array(parts) = try await parts(),
              case let .array(types) = parts[2],
              let first = types.first
        else {
            Issue.record("an object is written as a list of parts")

            return
        }

        parts[2] = .array(types + [first])

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a part is written short")
    func aPartWrittenShort() async throws {
        // Given. A real object with its last part dropped.
        guard case let .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(Array(parts.dropLast())), of: nil)
        }
    }

    @Test("is refused where a part is written long")
    func aPartWrittenLong() async throws {
        guard case let .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts + [.null]), of: nil)
        }
    }

    @Test("is refused where a numbering names one type twice")
    func aNumberingThatRepeats() async throws {
        // Given. A real object whose type numbering lists one name twice. The
        // numbering answers by position, so a swallowed name moves every number
        // after it onto some other declaration.
        guard case var .array(parts) = try await parts(),
              case var .array(numbering) = parts[11],
              case let .array(types) = numbering[0],
              let first = types.first
        else {
            Issue.record("an object writes its type numbering as a part")

            return
        }

        numbering[0] = .array(types + [first])
        parts[11] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
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
        parts[8] = .array(table)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where the format it is laid out as is not this one")
    func aFormatThisDoesNotRead() async throws {
        // Given. A real object stamped with a format this does not lay out.
        guard case let .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        // When / Then. The fields behind the stamp are this reading's own, so
        // what refuses is the stamp and nothing further in.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: .array([.int(Compiled.format + 1), .array(parts)]), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(answers) = parts[9],
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
        parts[9] = .array(answers)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a frame names fewer slots than it holds")
    func aFrameNamingTooFew() async throws {
        guard case var .array(parts) = try await parts(),
              case var .array(table) = parts[8],
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
        parts[8] = .array(table)

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a table is shorter than what it stands for")
    func aTableTooShort() async throws {
        guard case var .array(parts) = try await parts(), case let .array(table) = parts[8], !table.isEmpty else {
            Issue.record("an object writes its rows as a part")

            return
        }

        parts[8] = .array(table.dropLast())

        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where the spellings stand in an order the table does not")
    func declarationsOutOfStep() async throws {
        // Given. A document of two declarations, with the spellings swapped and
        // the rows left where they were. Each row still knows its own label, so
        // nothing but the two together can tell.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        guard case var .array(parts) = try await parts(of: sut),
              case let .array(declared) = parts[7],
              declared.count == 2
        else {
            Issue.record("an object writes its declared spellings as a part")

            return
        }

        parts[7] = .array(declared.reversed())

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
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
        parts[8] = .array(table)

        // When / Then. The row the call reaches is this document's own, so the
        // reading answers it and no link is needed.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a name is not in normal form")
    func aNameNotInNormalForm() async throws {
        // Given. A real object whose declared spelling is written in the
        // decomposed form. It reads alike and compares apart, so every order
        // and every lookup built on it would go quiet.
        guard case var .array(parts) = try await parts(), case let .array(declared) = parts[7], !declared.isEmpty else {
            Issue.record("an object writes its declared spellings as a part")

            return
        }

        parts[7] = .array([.string("app.entr\u{0079}\u{0301}")])

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a numbering counts a spelling the document does not declare")
    func aNumberingOffItsDocument() async throws {
        // Given. A real object whose numbering ends on some other spelling.
        // The declarations stand at the end of that list, so every self call
        // would reach whatever the link answers that name with.
        guard case var .array(parts) = try await parts(),
              case var .array(numbering) = parts[10],
              case let .array(spellings) = numbering[1],
              !spellings.isEmpty
        else {
            Issue.record("an object writes its numbering as a part")

            return
        }

        numbering[1] = .array(spellings.dropLast() + [.string("std.math.add")])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case let .array(types) = parts[2],
              types.count == 2
        else {
            Issue.record("an object writes its declared types in name order")

            return
        }

        parts[2] = .array(types.reversed())

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
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
        parts[8] = .array(table)

        // When / Then. Refused, rather than reaching the run that reads it.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a body stands sends of its own")
    func aBodyThatStandsSends() async throws {
        // Given. A real object with one send added to a row that has a body.
        // A body's calls are in its own code, so a list here is a fact about
        // some other kind of row.
        guard case var .array(parts) = try await parts(),
              case var .array(table) = parts[8],
              case var .array(row) = table[0],
              case let .array(sends) = row[5],
              sends.isEmpty
        else {
            Issue.record("an object writes a row's sends beside its implementation")

            return
        }

        row[5] = .array([.array([.int(0), .array([])])])
        table[0] = .array(row)
        parts[8] = .array(table)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(claims) = parts[5],
              case var .array(entry) = claims[0],
              case let .array(contracts) = entry[1],
              contracts.count == 2
        else {
            Issue.record("an object writes which contracts each type answers")

            return
        }

        entry[1] = .array(contracts.reversed())
        claims[0] = .array(entry)
        parts[5] = .array(claims)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10],
              case let .array(closing) = numbering[2],
              closing.count == 2
        else {
            Issue.record("an object writes where each declaration's closures begin")

            return
        }

        numbering[2] = .array(closing.reversed())
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("refuses at the run where a field step names one place and stands at another")
    func aFieldStepOffItsName() async throws {
        // Given. A body that reads one field of a record of two. The step holds
        // where the link put it and what it is called, and a write lands on the
        // name while a read stands at the place, so the two saying different
        // things is a value that comes back wrong rather than refused.
        let sut = try Module(
            types: ["app.Pair": .record(["x": .int, "y": .int])],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("pair"),
                        expression: .cast(
                            .record(["x": .literal(.int(1)), "y": .literal(.int(2))]),
                            as: .named("app.Pair"),
                            optional: false
                        )
                    )],
                    result: reference("pair", "x")
                )
            ]
        )

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case let .int(1) = operation[0],
              case var .array(address) = operation[1],
              case let .array(steps) = address[1],
              case var .array(step) = steps.first,
              case let .int(0) = step[0]
        else {
            Issue.record("an object writes a body that reads a field of a record")

            return
        }

        // The place moved off the name it is written beside.
        step[1] = .int(1)
        address[1] = .array([.array(step)])
        operation[1] = .array(address)
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts[8] = .array(table)

        // When. Nothing here is the reading's to know, so it reads.
        let read = try Compiled(written: stamped(parts), of: nil)
        let image = try Builder().link([read], entry: "app.entry", supplying: .none)

        // Then. The run refuses rather than answering the other field.
        await #expect(throws: (any Error).self) {
            try await Executor().run(image, arguments: [:])
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10],
              case let .array(sent) = numbering[0],
              sent.count == 2
        else {
            Issue.record("an object writes what its document sends")

            return
        }

        numbering[0] = .array(sent.reversed())
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(), let settled else {
            Issue.record("a module variable that starts as a closure settles one into a value")

            return
        }

        parts[12] = .array([.array([.string(settled.name.spelling), settled.value])])

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a closure is counted for a declaration that did not write it")
    func aClosureCountedForAnother() async throws {
        // Given. Two declarations, one of which writes a closure, with the
        // count moved onto the other. Every number still stands somewhere, so
        // nothing is out of range; what moves is which body owns it.
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10],
              case let .array(counts) = numbering[2],
              case let .array(entry) = counts.first,
              counts.count == 1
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[2] = .array([.array([.string("app.other"), entry[1]])])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[2] = .array([
            .array([.string("app.entry"), .int(.max - 1)]),
            .array([.string("app.other"), .int(1)])
        ])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10],
              case let .array(counts) = numbering[2],
              counts.count == 1
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[2] = .array(counts + [.array([.string("app.other"), .int(0)])])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10],
              case let .array(counts) = numbering[2],
              case let .array(entry) = counts.first,
              counts.count == 1
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[2] = .array([.array([entry[0], .int(4)])])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(numbering) = parts[10]
        else {
            Issue.record("an object writes how many closures each declaration wrote")

            return
        }

        numbering[2] = .array([
            .array([.string("app.entry"), .int(.max)]),
            .array([.string("app.other"), .int(.max)])
        ])
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
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

    @Test("is refused where the variables stand out of name order")
    func variablesOutOfOrder() async throws {
        // Given. Two module variables with the pair swapped. A body reaches one
        // by its number and never by its name, so the order is the fact and the
        // two would read each other's start.
        let sut = try Module(
            variables: ["app.one": .literal(.int(1)), "app.two": .literal(.int(2))],
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("app.one"))
            ]
        )

        guard case var .array(parts) = try await parts(of: sut),
              case let .array(variables) = parts[12],
              variables.count == 2
        else {
            Issue.record("an object writes what its variables start holding")

            return
        }

        parts[12] = .array(variables.reversed())

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a call reaches a number the document never gave")
    func aCallOffTheNumbering() async throws {
        // Given. A body that calls one of its own declarations, with the number
        // moved past everything this document numbered. What a number stands
        // for is the link's answer, but one never given is one no link answers.
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

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case let .int(11) = operation[0],
              case var .array(call) = operation[1]
        else {
            Issue.record("an object writes a body whose result is a call")

            return
        }

        call[0] = .int(9999)
        operation[1] = .array(call)
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts[8] = .array(table)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a body stands on a type number the document never gave")
    func aTypeNumberOffTheNumbering() async throws {
        // Given. A body that casts to a declared type, with the number moved
        // past everything this document numbered.
        let sut = try Module(
            types: ["app.Point": .record(["x": .int])],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(parameters: ["p": Parameter(type: .any)], returns: .named("app.Point")),
                    body: [],
                    result: .cast(reference("p"), as: .named("app.Point"), optional: false)
                )
            ]
        )

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(table) = parts[8],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case let .int(6) = operation[0],
              case var .array(type) = operation[2],
              case let .int(17) = type[0]
        else {
            Issue.record("an object writes a body that casts to a declared type")

            return
        }

        type[1] = .int(9999)
        operation[2] = .array(type)
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts[8] = .array(table)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where a place inside it addresses another document")
    func aPlaceOfAnotherDocument() async throws {
        // Given. A document that leans a type on a contract, so the object
        // holds a place, with that place moved onto some other document.
        let sut = try Module(
            types: ["app.Box": .record(["v": .int])],
            contracts: ["app.Show": ["show": Signature(returns: .int)]],
            claims: ["app.Box": ["app.Show"]],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(
                        binding: .constant("box"),
                        expression: .cast(
                            .record(["v": .literal(.int(1))]),
                            as: .named("app.Box"),
                            optional: false
                        )
                    )],
                    result: .call(Call(receiver: reference("box"), selector: "app.Show.show"))
                ),
                "app.Box.show": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("app.Box"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        guard case var .array(parts) = try await parts(of: sut),
              case var .array(leaned) = parts[6],
              case var .array(entry) = leaned.first,
              case var .array(place) = entry[2],
              leaned.count == 1
        else {
            Issue.record("an object writes where each pair its bodies lean on was written")

            return
        }

        place[0] = .array([.bytes([0x07])])
        entry[2] = .array(place)
        leaned[0] = .array(entry)
        parts[6] = .array(leaned)

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where another Warp wrote it")
    func anotherRuntime() async throws {
        // Given. A real object, stamped as the work of a build this is not.
        guard case let .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        let elsewhere: Value = .array([
            .int(Compiled.format),
            .string("warp-swift 99.0.0 (0000000)"),
            .array(parts)
        ])

        // When / Then. Refused before anything laid out by this runtime's rules
        // is read against them.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: elsewhere, of: nil)
        }
    }

    @Test("is refused where what it leaned on stands out of order")
    func dependenciesOutOfOrder() async throws {
        // Given. A real object whose two dependencies are written the other
        // way round. Both name the same pair, so a reading that took either
        // order would let two writings say one object.
        guard case var .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        parts[1] = .array([.bytes([0x02]), .bytes([0x01])])

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    @Test("is refused where it leans on one object twice")
    func dependenciesRepeated() async throws {
        // Given. A real object naming one of them twice. What it leaned on is
        // a set, and a set written down twice is a writing no set makes.
        guard case var .array(parts) = try await parts() else {
            Issue.record("an object is written as a list of parts")

            return
        }

        parts[1] = .array([.bytes([0x01]), .bytes([0x01])])

        // When / Then.
        #expect(throws: ObjectRefused.self) {
            try Compiled(written: stamped(parts), of: nil)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The parts an object writes, with the format it is stamped with taken
    // off, so that a test bends what it means to bend.
    private func parts() async throws -> Value {
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

    private func parts(of module: Module) async throws -> Value {
        let compiled = try await builder.compile([module] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("app.entry") }),
              case let .array(written) = mine.written,
              written.count == 3
        else {
            throw ObjectMissing()
        }

        return written[2]
    }

    private func stamped(_ parts: [Value]) -> Value {
        .array([.int(Compiled.format), .string(Compiled.runtime), .array(parts)])
    }
}

private struct ObjectMissing: Error { }
