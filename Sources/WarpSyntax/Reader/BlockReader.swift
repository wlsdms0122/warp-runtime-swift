//
//  BlockReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// `body:` and `result:`. The pair every construct that runs a body writes.
public struct BlockReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case result
    }

    // MARK: - Property
    public let block: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "block")

        try self.init(reading: decoder)
    }

    // The same keys read beside others the caller has already held the
    // record to.
    init(reading decoder: Decoder) throws {
        self.block = Block(
            body: try decoder.descendingIfPresent(to: CodingKeys.body)?
                .read(BodyReader.self)
                .body ?? [],
            result: try decoder.descendingIfPresent(to: CodingKeys.result)?
                .read(ExpressionReader.self)
                .expression
        )
    }

    // MARK: - Public
    // MARK: - Private
}
