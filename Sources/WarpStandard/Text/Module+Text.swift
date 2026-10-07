//
//  Module+Text.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let text = bundled(nativeText, with: "text")

    private static let nativeText = Module(
        unchecked: Draft(
            description: "Procedures about strings.",
            procedures: [
                "Standard.Text.decoded": Procedure(
                    description: "The bytes read as text in a named encoding.",
                    signature: Signature(of: DecodedQuery.self, returns: .string),
                    implementation: .query(DecodedQuery())
                ),
                "Standard.Text.encoded": Procedure(
                    description: "The text written out as bytes in a named encoding.",
                    signature: Signature(of: EncodedQuery.self, returns: .bytes),
                    implementation: .query(EncodedQuery())
                ),
                "Standard.Text.text": Procedure(
                    description: "How a value reads as text.",
                    signature: Signature(of: TextQuery.self, returns: .string),
                    implementation: .query(TextQuery())
                ),
                "Standard.Text.characters": Procedure(
                    description: "The text as an array of its characters.",
                    signature: Signature(
                        of: CharactersQuery.self,
                        returns: .array(.string)
                    ),
                    implementation: .query(CharactersQuery())
                ),
                "Standard.Text.uppercased": Procedure(
                    description: "The text in upper case.",
                    signature: Signature(of: UppercasedQuery.self, returns: .string),
                    implementation: .query(UppercasedQuery())
                ),
                "Standard.Text.lowercased": Procedure(
                    description: "The text in lower case.",
                    signature: Signature(of: LowercasedQuery.self, returns: .string),
                    implementation: .query(LowercasedQuery())
                ),
                "Standard.Text.trimmed": Procedure(
                    description: "The text without surrounding whitespace.",
                    signature: Signature(of: TrimmedQuery.self, returns: .string),
                    implementation: .query(TrimmedQuery())
                ),
                "Standard.Text.joined": Procedure(
                    description: "The strings written one after another.",
                    signature: Signature(of: JoinedQuery.self, returns: .string),
                    implementation: .query(JoinedQuery())
                )
            ]
        ),
        builtin: true
    )
}
