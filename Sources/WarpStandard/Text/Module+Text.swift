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
            procedures: [
                "Standard.Text.decoded": Procedure(
                    signature: Signature(
                        of: DecodedQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(DecodedQuery())
                ),
                "Standard.Text.encoded": Procedure(
                    signature: Signature(
                        of: EncodedQuery.self,
                        returns: .array(.int),
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(EncodedQuery())
                ),
                "Standard.Text.text": Procedure(
                    signature: Signature(
                        of: TextQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(TextQuery())
                ),
                "Standard.Text.characters": Procedure(
                    signature: Signature(
                        of: CharactersQuery.self,
                        returns: .array(.string),
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(CharactersQuery())
                ),
                "Standard.Text.uppercased": Procedure(
                    signature: Signature(
                        of: UppercasedQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(UppercasedQuery())
                ),
                "Standard.Text.lowercased": Procedure(
                    signature: Signature(
                        of: LowercasedQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(LowercasedQuery())
                ),
                "Standard.Text.trimmed": Procedure(
                    signature: Signature(
                        of: TrimmedQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(TrimmedQuery())
                ),
                "Standard.Text.joined": Procedure(
                    signature: Signature(
                        of: JoinedQuery.self,
                        returns: .string,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(JoinedQuery())
                )
            ]
        ),
        builtin: true
    )
}
