//
//  ParameterReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A parameter, written as a mapping of the name its body reads it by and its
// type.
struct ParameterReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case name
        case type
    }

    // MARK: - Property
    // Omitting the type says `Any`, the one way a document says it.
    let parameter: Parameter

    // The type parameters its type names, where a bound may stand beside the
    // first.
    let namings: [TypeReader.Naming]

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "parameter")

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try Name.read(try container.decode(String.self, forKey: .name), at: decoder.steps)
        let type = try container.decodeIfPresent(TypeReader.Written.self, forKey: .type)

        self.parameter = Parameter(name: name, type: type?.type ?? .any)
        self.namings = type?.namings ?? []
    }

    // MARK: - Public
    // MARK: - Private
}
