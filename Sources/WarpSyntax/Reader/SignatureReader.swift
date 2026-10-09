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
        self.signature = Signature(
            parameters: try decoder.singleValueContainer()
                .decode([ParameterReader].self)
                .map(\.parameter)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
