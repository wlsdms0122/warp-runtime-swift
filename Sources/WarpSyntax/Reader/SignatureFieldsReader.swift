//
//  SignatureFieldsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/10/26.
//

import Foundation
import Warp

// What a signature is written as beside the keys a procedure and a
// contract's procedure each write of their own: `parameters`, `returns`,
// `bounds` and `sameTypes`. Absent `parameters` is an empty signature, not an
// absent one.
struct SignatureFieldsReader {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
        case bounds
        case sameTypes
    }

    // MARK: - Property
    let signature: Signature

    // MARK: - Initializer
    // Read beside other keys the caller has already held the mapping to.
    init(reading decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bounds = try decoder.descendingIfPresent(to: CodingKeys.bounds)

        self.signature = Signature(
            parameters: try container.decodeIfPresent([ParameterReader].self, forKey: .parameters)?
                .map(\.parameter) ?? [],
            returns: try container.decodeIfPresent(TypeReader.self, forKey: .returns)?.type,
            bounds: try BoundsReader().bounds(
                try bounds?.read([Name: String].self),
                in: decoder.notation,
                at: bounds?.steps ?? decoder.steps
            ),
            sameTypes: try decoder.descendingIfPresent(to: CodingKeys.sameTypes)?
                .read([Name: TypeReader].self).mapValues(\.type) ?? [:]
        )
    }

    // MARK: - Public
    // MARK: - Private
}
