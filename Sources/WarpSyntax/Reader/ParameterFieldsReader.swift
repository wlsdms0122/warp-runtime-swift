//
//  ParameterFieldsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/23/26.
//

import Foundation
import Warp

// What a parameter says beside its name: the type. Read apart from the name
// because the pair form a notation offers writes the name as the key and this
// under it.
struct ParameterFieldsReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case type
    }

    // MARK: - Property
    // Omitting `type:` says `Any`, the one way a document says it.
    let type: TypeExpression

    // The type parameters the type names, where a bound may stand beside the
    // first.
    let namings: [TypeReader.Naming]

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "parameter"
        )

        try self.init(reading: decoder)
    }

    // The same fields read beside others the caller has already held the
    // mapping's keys to.
    init(reading decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decodeIfPresent(TypeReader.self, forKey: .type)?.bounded

        self.type = type?.type ?? .any
        self.namings = type?.namings ?? []
    }

    // MARK: - Public
    // MARK: - Private
}
