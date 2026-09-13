//
//  ArtifactReadingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What a reading of an artifact refuses.
//
// An artifact is this runtime's own writing, so what is asked here is what
// happens when the bytes are not that. Each case bends one field of a real
// artifact, because a writing built by hand would prove only that the reading
// refuses something it was never handed.
@Suite("An artifact whose writing is not one")
struct ArtifactReadingTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a count is written below zero")
    func aCountBelowZero() throws {
        // Given. A real artifact whose numbering counts its closures below zero.
        guard case var .array(parts) = try parts(),
              case var .array(numbering) = parts[10],
              numbering.count == 3
        else {
            Issue.record("an artifact writes its numbering as a part")

            return
        }

        numbering[2] = .int(-1)
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a name keys two entries")
    func aNameWrittenTwice() throws {
        // Given. A real artifact whose declared types list repeats one entry.
        guard case var .array(parts) = try parts(),
              case let .array(types) = parts[1],
              let first = types.first
        else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        parts[1] = .array(types + [first])

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a part is written short")
    func aPartWrittenShort() throws {
        // Given. A real artifact with its last part dropped.
        guard case let .array(parts) = try parts() else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(Array(parts.dropLast())))
        }
    }

    @Test("is refused where a part is written long")
    func aPartWrittenLong() throws {
        guard case let .array(parts) = try parts() else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts + [.null]))
        }
    }

    @Test("is refused where a numbering names one type twice")
    func aNumberingThatRepeats() throws {
        // Given. A real artifact whose type numbering lists one name twice. The
        // numbering answers by position, so a swallowed name moves every number
        // after it onto some other declaration.
        guard case var .array(parts) = try parts(),
              case var .array(numbering) = parts[11],
              case let .array(types) = numbering[0],
              let first = types.first
        else {
            Issue.record("an artifact writes its type numbering as a part")

            return
        }

        numbering[0] = .array(types + [first])
        parts[11] = .array(numbering)

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a body stands past its frame")
    func aBodyPastItsFrame() throws {
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

        guard case var .array(parts) = try parts(of: sut),
              case var .array(table) = parts[7],
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
        parts[7] = .array(table)

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where the format it is laid out as is not this one")
    func aFormatThisDoesNotRead() throws {
        // Given. A real artifact stamped with a format this does not lay out.
        guard case let .array(parts) = try parts() else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        // When / Then. The fields behind the stamp are this reading's own, so
        // what refuses is the stamp and nothing further in.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array([.int(Compiled.format + 1), .array(parts)]))
        }
    }

    @Test("is refused where a layout's names are not in order")
    func aLayoutOutOfOrder() throws {
        // Given. A declaration that writes no `returns`, so what the build read
        // off its body stands in the artifact as a lowered record, layout and
        // types apart.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(
                    body: [],
                    result: .record(["a": .literal(.int(1)), "b": .literal(.string("s"))])
                )
            ]
        )

        guard case var .array(parts) = try parts(of: sut),
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
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a frame names fewer slots than it holds")
    func aFrameNamingTooFew() throws {
        guard case var .array(parts) = try parts(),
              case var .array(table) = parts[7],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(frame) = implementation[2],
              case let .array(names) = frame[3],
              !names.isEmpty
        else {
            Issue.record("an artifact writes a row's frame beside its body")

            return
        }

        frame[3] = .array(names.dropLast())
        implementation[2] = .array(frame)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts[7] = .array(table)

        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a table is shorter than what it stands for")
    func aTableTooShort() throws {
        guard case var .array(parts) = try parts(), case let .array(table) = parts[7], !table.isEmpty else {
            Issue.record("an artifact writes its rows as a part")

            return
        }

        parts[7] = .array(table.dropLast())

        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where a call list stands for no declaration")
    func callsThatStandForNothing() throws {
        guard case var .array(parts) = try parts(), case let .array(calls) = parts[8] else {
            Issue.record("an artifact writes what each declaration calls as a part")

            return
        }

        parts[8] = .array(calls + [.array([])])

        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused where the spellings stand in an order the table does not")
    func declarationsOutOfStep() throws {
        // Given. A document of two declarations, with the spellings swapped and
        // the rows left where they were. Each row still knows its own label, so
        // nothing but the two together can tell.
        let sut = try Module(
            procedures: [
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.other": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        guard case var .array(parts) = try parts(of: sut),
              case let .array(declared) = parts[6],
              declared.count == 2
        else {
            Issue.record("an artifact writes its declared spellings as a part")

            return
        }

        parts[6] = .array(declared.reversed())

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: stamped(parts))
        }
    }

    @Test("is refused at the link where a call stands more arguments than its callee takes")
    func aCallStandingTooMany() throws {
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

        guard case var .array(parts) = try parts(of: sut),
              case var .array(table) = parts[7],
              case var .array(row) = table[0],
              case var .array(implementation) = row[6],
              case var .array(body) = implementation[1],
              case var .array(result) = body[1],
              case var .array(operation) = result[0],
              case var .array(call) = operation[1],
              case let .array(arguments) = call[2]
        else {
            Issue.record("an artifact writes a body whose result is a call")

            return
        }

        call[2] = .array(arguments + [.array([])])
        operation[1] = .array(call)
        result[0] = .array(operation)
        body[1] = .array(result)
        implementation[1] = .array(body)
        row[6] = .array(implementation)
        table[0] = .array(row)
        parts[7] = .array(table)

        // When. The artifact reads, because nothing here is the reading's to
        // know: which row the call reaches is the link's answer.
        let read = try Compiled(written: stamped(parts))

        // Then. The link refuses it, and no run begins. A link refusal, not an
        // artifact's: this one asks the same of a document nobody wrote down,
        // and it says which call it is about.
        #expect(throws: BuildError.self) {
            try Builder().link([read], entry: "app.entry", supplying: .none)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The parts an artifact writes, with the format it is stamped with taken
    // off, so that a test bends what it means to bend.
    private func parts() throws -> Value {
        try parts(of: try Module(
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

    private func parts(of module: Module) throws -> Value {
        let compiled = try builder.compile([module] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("app.entry") }),
              case let .array(written) = try mine.written,
              written.count == 2
        else {
            throw ArtifactMissing()
        }

        return written[1]
    }

    private func stamped(_ parts: [Value]) -> Value {
        .array([.int(Compiled.format), .array(parts)])
    }
}

private struct ArtifactMissing: Error { }
