//
//  BlockReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// `body:` and `result:`, read beside the other keys of a procedure.
struct BlockReader {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case result
    }

    // MARK: - Property
    let block: Block

    // MARK: - Initializer
    // The caller has already held the mapping to its own keys and these.
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
