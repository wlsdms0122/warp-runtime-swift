//
//  ValueReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// Data as a document spells it: the value the reading stands on, taken
// whole.
struct ValueReader: Decodable {
    // MARK: - Property
    let value: Value

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.value = try decoder.valueDecoder.value
    }

    // MARK: - Public
    // MARK: - Private
}
