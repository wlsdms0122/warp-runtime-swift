//
//  ParameterFieldsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/23/26.
//

import Foundation
import Warp

// What a parameter says beside its name: the type and a description. Read apart from the name because the pair form a notation
// offers writes the name as the key and these under it.
struct ParameterFieldsReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case description
    }

    // MARK: - Property
    // Omitting `type:` declares nothing, which is not the same as declaring
    // `Any`. Both take whatever arrives; only one of them says so.
    let type: TypeExpression?
    let description: String?

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "parameter"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.type = try container.decodeIfPresent(TypeReader.self, forKey: .type)?.type
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    // MARK: - Public
    // MARK: - Private
}
