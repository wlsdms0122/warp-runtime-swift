//
//  ContractReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A contract: the types and the procedures a type that answers it gives, by
// name, and what each type it asks is held to.
struct ContractReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case types
        case bounds
        case procedures
    }

    // MARK: - Property
    let contract: Contract

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "contract")

        let bounds = try decoder.descendingIfPresent(to: CodingKeys.bounds)
        let procedures = try decoder.descendingIfPresent(to: CodingKeys.procedures)

        self.contract = Contract(
            procedures: try procedures?.read([Name: ContractProcedureReader].self).mapValues(\.procedure) ?? [:],
            types: Set(try Self.types(from: decoder.descendingIfPresent(to: CodingKeys.types))),
            bounds: try BoundsReader().bounds(
                try bounds?.read([Name: String].self),
                in: decoder.notation,
                at: bounds?.steps ?? decoder.steps
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
    // The names of the types the contract asks, each as it is written: a type
    // member's name, which a notation does not qualify.
    private static func types(from decoder: Decoder?) throws -> [Name] {
        guard let decoder else { return [] }

        return try decoder.read([String].self).enumerated().map { position, spelling in
            try Name.read(spelling, at: decoder.steps + [.index(position)])
        }
    }
}
