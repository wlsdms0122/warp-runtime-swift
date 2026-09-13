//
//  ArtifactWritingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Testing
import Warp
import WarpSyntax

// Whether an artifact survives being written down.
//
// The corpus is the specification's cases because that is the widest body of
// programs there is: every construct, every standard procedure, and the
// vocabulary a host brings. What is asked of them here is this implementation's
// own question, which is why it is asked from here and not from the runner
// beside it. That runner is a document another implementation could write its
// own copy of, and no other implementation has one of these.
@Suite("An artifact written down")
struct ArtifactWritingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is one value, and reads back as the program it was", arguments: try Case.all())
    func survivesBeingWritten(_ sut: Case) async throws {
        // Given. A case the build refuses has no artifact to write, and that it
        // is refused is the runner's question rather than this one.
        guard case let .answers(expected) = sut.expectation else { return }

        let builder = Builder()
        let modules = try sut.modules()
        let compiled = try builder.compile(modules)

        // When. Each artifact written to bytes and read back out of them. A
        // document of the specification's is one an artifact can hold, so one
        // that answers nothing here is the failure rather than a case to skip.
        let bytes = try compiled.map { one in
            guard let written = one.written else { throw ArtifactUnwritable() }

            return try BinaryEncoding.data(from: written)
        }
        let read = try bytes.map { written in
            try Compiled(written: try BinaryEncoding.value(from: written))
        }

        // Then. One artifact is one writing, both ways.
        for (before, after) in zip(bytes, read) {
            #expect(before == (try? BinaryEncoding.data(from: after.written ?? .null)), "\(sut.name)")
        }

        // And the program those artifacts build answers what the written ones
        // do, which is the whole of what an artifact is for.
        let image = try builder.link(read, entry: "entry", supplying: Supplying(modules))
        let answered = try await Executor().run(image, arguments: sut.arguments)

        #expect(answered == expected, "\(sut.name): \(sut.note)")
    }

    // MARK: - Public
    // MARK: - Private
}

private struct ArtifactUnwritable: Error { }
