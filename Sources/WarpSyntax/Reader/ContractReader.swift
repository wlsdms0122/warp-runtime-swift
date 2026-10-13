//
//  ContractReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A contract: the types and the procedures a type that answers it gives, by
// name, and what each type it asks is held to, beside its name under `types`.
struct ContractReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case types
        case procedures
    }

    // MARK: - Property
    let contract: Contract

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "contract")

        let procedures = try decoder.descendingIfPresent(to: CodingKeys.procedures)
        let types = try decoder.descendingIfPresent(to: CodingKeys.types).map(IntroducedNamesReader.init(reading:))

        self.contract = Contract(
            procedures: try procedures?.read([Name: ContractProcedureReader].self).mapValues(\.procedure) ?? [:],
            types: Set(types?.names ?? []),
            bounds: types?.bounds ?? [:]
        )
    }

    // MARK: - Public
    // MARK: - Private
}
