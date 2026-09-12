//
//  Module+Text.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let text = try! Module(
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
            "std.text.startsWith": Procedure(
                description: "Whether a string begins with another.",
                signature: Signature(of: StartsWithQuery.self, receiver: .of, returns: .bool),
                implementation: .query(StartsWithQuery())
            ),
            "std.text.regex": Procedure(
                description: "Whether a string matches a pattern.",
                signature: Signature(of: RegexQuery.self, receiver: .of, returns: .bool),
                implementation: .query(RegexQuery())
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
            "std.text.split": Procedure(
                description: "The text cut on a separator.",
                signature: Signature(
                    of: SplitQuery.self,
                    receiver: .of,
                    returns: .array(.string)
                ),
                implementation: .query(SplitQuery())
            ),
            "std.text.joined": Procedure(
                description: "The strings written one after another.",
                signature: Signature(of: JoinedQuery.self, receiver: .of, returns: .string),
                implementation: .query(JoinedQuery())
            ),
            "std.text.replacing": Procedure(
                description: "Every occurrence of a piece swapped for another.",
                signature: Signature(of: ReplacingQuery.self, receiver: .of, returns: .string),
                implementation: .query(ReplacingQuery())
            )
        ]
    )
}
