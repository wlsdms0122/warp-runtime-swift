//
//  DecodedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// Bytes read as text in a named encoding. This can refuse: bytes carry no
// promise of being text, and completing a broken sequence with replacement
// characters would answer a text nobody sent.
struct DecodedQuery: Query {
    // What this takes: the bytes, and the encoding to read them in.
    enum Parameters: Int, ParameterSet {
        case of
        case encoding

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(name: "of", type: .bytes)

            case .encoding:
                return Parameter(name: "encoding", type: .nullable(.string), candidates: ["utf8"])
            }
        }
    }

    // MARK: - Property
    private let encoding = Encoding("decoded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try encoding.named(question[.encoding])

        guard let bytes = question[.of].bytes else { return nil }

        guard let text = encoding.text(of: bytes) else {
            throw ExecutionError("the bytes are not utf8 text")
        }

        return .string(text)
    }

    // MARK: - Private
}
