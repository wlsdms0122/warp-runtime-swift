//
//  IdentityTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// Which document a document is.
@Suite("A document's identity")
struct IdentityTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the digest is the published one, so two implementations answer alike")
    func theDigestIsTheStandardOne() {
        // Given. The vectors FIPS 180-4 publishes, and the empty input, which
        // is the one every implementation gets wrong differently. A digest
        // agreeing with this file and with nothing else would be an identity
        // only this runtime could work out.
        let cases = [
            ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015a"
                + "d"),
            (
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
            )
        ]

        // When / Then
        for (written, expected) in cases {
            #expect(Identity(SHA256().digest(of: Data(written.utf8))).rendered == expected)
        }

        // And a message longer than one block, where the schedule is what is
        // being tested rather than the padding
        let long = String(repeating: "a", count: 1000)

        #expect(
            Identity(SHA256().digest(of: Data(long.utf8))).rendered
                == "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3"
        )
    }

    @Test("one document is one identity, whichever way it was written down")
    func oneDocumentIsOneIdentity() throws {
        // Given. The same document, and a text writing of it read back. A
        // notation is not part of what a program is, so nothing about how it
        // arrived may reach the answer.
        let document = Value.dictionary([
            "warp": .int(1),
            "imports": .array([]),
            "procedures": .dictionary(["entry": .dictionary(["body": .array([.dictionary(["value": .dictionary(["return": .int(1)])])])])])
        ])

        let throughText = try TextEncoding().value(from: try TextEncoding().text(from: document))
        let throughBytes = try BinaryEncoding().value(from: try BinaryEncoding().data(from: document))

        // When / Then
        #expect(try Identity.of(throughText) == Identity.of(document))
        #expect(try Identity.of(throughBytes) == Identity.of(document))
    }

    @Test("two documents that say different things are two identities")
    func differentDocumentsDiffer() throws {
        // Given. Two documents that declare different things.
        let first = Value.dictionary([
            "warp": .int(1),
            "procedures": .dictionary(["charge": .dictionary(["body": .array([])])])
        ])

        let second = Value.dictionary([
            "warp": .int(1),
            "procedures": .dictionary(["refund": .dictionary(["body": .array([])])])
        ])

        // When / Then
        #expect(try Identity.of(first) != Identity.of(second))
    }

    @Test("an identity reads short where a person sees one, and whole where it is compared")
    func anIdentityReadsShort() {
        // Given
        let sut = Identity(SHA256().digest(of: Data("abc".utf8)))

        // When / Then
        #expect(sut.short == "ba7816bf8f01")
        #expect(sut.rendered.count == 64)
        #expect(sut.description == sut.short)
    }

    // MARK: - Public
    // MARK: - Private
}
