//
//  ContractProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Warp

// One procedure of a contract: its signature alone, read the way a
// declaration's is, `bounds` included, and held at the load to what a
// contract's procedure may say.
struct ContractProcedureReader: Decodable {
    // MARK: - Property
    let procedure: Signature

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: SignatureFieldsReader.CodingKeys.self,
            context: "contract procedure"
        )

        self.procedure = try SignatureFieldsReader(reading: decoder).signature
    }

    // MARK: - Public
    // MARK: - Private
}
