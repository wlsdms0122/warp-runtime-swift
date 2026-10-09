//
//  ContractProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Warp

// One procedure of a contract: what a call may hand it and what it answers,
// and what it asks beyond that, `const` and `isolated`, each a bool. Its
// signature is read the way a declaration's is, `bounds` included, and held
// at the load to what a contract's procedure may say.
public struct ContractProcedureReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
        case bounds
        case const
        case isolated
        case failing
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
            signature: try SignatureFieldsReader(reading: decoder).signature,
            constness: try container.decodeIfPresent(Bool.self, forKey: .const) == true ? .const : .unstated,
            isolation: try container.decodeIfPresent(Bool.self, forKey: .isolated) == true ? .isolated : .unstated,
            failing: Set(try container.decodeIfPresent([String].self, forKey: .failing) ?? [])
        )
    }

    // MARK: - Public
    // MARK: - Private
}
