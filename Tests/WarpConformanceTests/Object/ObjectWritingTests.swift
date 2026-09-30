//
//  ObjectWritingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Testing
import Warp
import WarpSyntax

// Whether an object survives being written down.
//
// The corpus is the specification's cases because that is the widest body of
// programs there is: every construct, every standard procedure, and the
// vocabulary a host brings. What is asked of them here is this implementation's
// own question, which is why it is asked from here and not from the runner
// beside it. That runner is a document another implementation could write its
// own copy of, and no other implementation has one of these.
@Suite("An object written down")
struct ObjectWritingTests {
    private struct ObjectNotWritten: Error { }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is one value, and reads back as the program it was", arguments: try Case.all())
    func survivesBeingWritten(_ sut: Case) async throws {
        // Given. A case the build refuses has no object to write, and that it
        // is refused is the runner's question rather than this one.
        guard case let .program(program) = sut.asked, case let .answers(expected) = program.expectation else { return }

        let builder = Builder(fingerprinting: Fingerprint.of)
        let modules = try await program.modules()
        let compiled = try await builder.compile(modules)

        // When. Each object written to bytes and read back out of them. A
        // document of the specification's is one an object can hold, so one
        // that answers nothing here is the failure rather than a case to skip.
        let bytes = try compiled.map { one in
            guard let written = one.written else { throw ObjectNotWritten() }

            return try BinaryEncoding().data(from: written)
        }
        let read = try zip(bytes, compiled).map { written, one in
            try Compiled(written: try BinaryEncoding().value(from: written), of: one.identity, fingerprint: one.fingerprint)
        }

        // Then. One object is one writing, both ways.
        for (before, after) in zip(bytes, read) {
            #expect(before == (try? BinaryEncoding().data(from: after.written ?? .null)), "\(sut.name)")
        }

        // And the program those objects build answers what the written ones
        // do, which is the whole of what an object is for.
        let image = try builder.link(read, supplying: Supplying(modules))
        let answered = try await Executor().run(image, entry: "entry", arguments: program.arguments)

        #expect(answered == expected, "\(sut.name): \(sut.note)")
    }

    // MARK: - Public
    // MARK: - Private
}
