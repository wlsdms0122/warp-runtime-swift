//
//  OwnVocabularySpelling.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

// A spelling with one key of its own, `holds`, reaching a procedure no
// standard bundle declares, so what it owes is told apart from what the
// standard table owes.
struct OwnVocabularySpelling: ExpressionSpelling {
    // MARK: - Property
    let vocabulary: Set<Name> = ["Example.holds"]

    // MARK: - Initializer
    // MARK: - Public
    func claims(_ names: Set<Name>, in notation: Notation) -> Bool {
        names.contains("holds")
    }

    func expression(from decoder: Decoder, in notation: Notation) throws -> Warp.Expression {
        .call(
            Call(
                selector: "Example.holds",
                arguments: [
                    try decoder.container(keyedBy: AnyCodingKey.self)
                        .decode(ExpressionReader.self, forKey: AnyCodingKey(stringValue: "holds"))
                        .expression
                ]
            )
        )
    }

    // MARK: - Private
}
