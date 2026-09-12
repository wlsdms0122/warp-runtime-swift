//
//  RequirementReader.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// One word of a contract: what a call may hand it and what it answers.
//
// No `receiver` and no `bounds`. The receiver is the type that satisfies the
// contract, which is the whole point of the word being in one, and the bound a
// type parameter carries is owned by the signature that declares it.
public struct RequirementReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
    }

    // MARK: - Property
    public let signature: Signature

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "contract word"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.signature = Signature(
            parameters: try container
                .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                .signature.parameters ?? [:],
            returns: try container
                .decodeIfPresent(TypeReader.self, forKey: .returns)?
                .type
        )
    }

    // MARK: - Public
    // MARK: - Private
}
