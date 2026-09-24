//
//  OneSpellingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// A document is read in the one spelling the writer writes for what it says,
// and a refusal says where it parts and what the one spelling writes there.
@Suite("A document is read in its one spelling")
struct OneSpellingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a key written with what its absence means is refused, naming nothing as the one spelling")
    func aDefaultWrittenOutIsRefused() async {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["access": "internal", "result": 1]]
        ]

        // When / Then
        await #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            let refusal = error as? ReadingError

            return refusal?.place?.rendered == "procedures.entry.access"
                && "\(error)".contains("The one way writes nothing")
        }
    }

    @Test("a list written out of its order is refused, naming what the one spelling writes there")
    func aListOutOfOrderIsRefused() async {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": ["std.text.text", "std.logic.not"],
            "procedures": [
                "entry": [
                    "result": [
                        "call": [
                            "arguments": [["call": ["arguments": [true], "procedure": "std.logic.not"]]],
                            "procedure": "std.text.text"
                        ]
                    ]
                ]
            ]
        ]

        // When / Then
        await #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            "\(error)".contains("imports[0]") && "\(error)".contains("The one way writes \"std.logic.not\"")
        }
    }

    // MARK: - Private
}
