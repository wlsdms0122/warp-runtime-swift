//
//  ContractProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Warp

// One procedure of a contract: what a call may hand it and what it answers,
// and what it asks beyond that, `const` and `isolated`, each a bool.
//
// No `bounds`: the bound a type parameter carries is owned by the signature
// that declares it.
public struct ContractProcedureReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
        case const
        case isolated
    }

    // MARK: - Property
    public let procedure: ContractProcedure

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "contract procedure"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.procedure = ContractProcedure(
            signature: Signature(
                parameters: try container
                    .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                    .signature.parameters ?? [],
                returns: try container
                    .decodeIfPresent(TypeReader.self, forKey: .returns)?
                    .type
            ),
            constness: try container.decodeIfPresent(Bool.self, forKey: .const) == true ? .const : .unstated,
            isolation: try container.decodeIfPresent(Bool.self, forKey: .isolated) == true ? .isolated : .unstated
        )
    }

    // MARK: - Public
    // MARK: - Private
}
