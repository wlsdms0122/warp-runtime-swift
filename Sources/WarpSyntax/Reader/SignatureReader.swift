//
//  SignatureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The `parameters` of a declaration: a list, in the order the author wrote
// them, which is the order a value of the declaration is applied in.
public struct SignatureReader: Decodable {
    // MARK: - Property
    public let signature: Signature

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let parameters = try decoder.singleValueContainer()
            .decode([ParameterReader].self)
            .map(\.parameter)

        // Two parameters under one name would be one name the body reads two
        // ways, so the reading refuses the second before a body can.
        for (position, parameter) in parameters.enumerated()
        where parameters[..<position].contains(where: { earlier in earlier.name == parameter.name }) {
            throw ReadingError(
                "parameter '\(parameter.name)' is declared twice",
                at: decoder.steps + [.index(position)]
            )
        }

        self.signature = Signature(parameters: parameters)
    }

    // MARK: - Public
    // MARK: - Private
}
