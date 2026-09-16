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

    private static let nativeText = try! Module(
        description: "Procedures about strings.",
        procedures: [
            "std.text.decoded": Procedure(
                description: "The bytes read as text in a named encoding.",
                signature: Signature(of: DecodedQuery.self, receiver: .of, returns: .string),
                implementation: .query(DecodedQuery())
            ),
            "std.text.encoded": Procedure(
                description: "The text written out as bytes in a named encoding.",
                signature: Signature(of: EncodedQuery.self, receiver: .of, returns: .bytes),
                implementation: .query(EncodedQuery())
            ),
            "std.text.text": Procedure(
                description: "How a value reads as text.",
                signature: Signature(of: SpellingQuery.self, receiver: .of, returns: .string),
                implementation: .query(SpellingQuery())
            ),
            "std.text.regex": Procedure(
                description: "Whether a string matches a pattern.",
                signature: Signature(of: RegexQuery.self, receiver: .of, returns: .bool),
                implementation: .query(RegexQuery())
            ),
            "std.text.characters": Procedure(
                description: "The text as an array of its characters.",
                signature: Signature(
                    of: CharactersQuery.self,
                    receiver: .of,
                    returns: .array(.string)
                ),
                implementation: .query(CharactersQuery())
            ),
            "std.text.uppercased": Procedure(
                description: "The text in upper case.",
                signature: Signature(of: UppercasedQuery.self, receiver: .of, returns: .string),
                implementation: .query(UppercasedQuery())
            ),
            "std.text.lowercased": Procedure(
                description: "The text in lower case.",
                signature: Signature(of: LowercasedQuery.self, receiver: .of, returns: .string),
                implementation: .query(LowercasedQuery())
            ),
            "std.text.trimmed": Procedure(
                description: "The text without surrounding whitespace.",
                signature: Signature(of: TrimmedQuery.self, receiver: .of, returns: .string),
                implementation: .query(TrimmedQuery())
            ),
            "std.text.joined": Procedure(
                description: "The strings written one after another.",
                signature: Signature(of: JoinedQuery.self, receiver: .of, returns: .string),
                implementation: .query(JoinedQuery())
            )
        ]
    )
}
