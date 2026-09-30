//
//  OwnVocabularyConditions.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

// A spelling with one key of its own, `holds`, reaching a procedure no
// standard bundle declares, so what it owes is told apart from what the
// standard table owes.
struct OwnVocabularyConditions: ExpressionSpelling {
    // MARK: - Property
    let vocabulary: Set<Name> = ["example.holds"]

    // MARK: - Initializer
    // MARK: - Public
    func claims(_ names: Set<Name>, in notation: Notation) -> Bool {
        names.contains("holds")
    }

    func expression(from decoder: Decoder) throws -> Warp.Expression {
        .call(
            Call(
                selector: "example.holds",
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
