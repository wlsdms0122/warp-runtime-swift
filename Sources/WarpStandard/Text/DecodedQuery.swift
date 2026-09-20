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
        case encoding
        case of

        var name: Name {
            switch self {
            case .encoding:
                return "encoding"

            case .of:
                return "of"
            }
        }

        var declared: Parameter {
            switch self {
            case .encoding:
                return Parameter(type: .string, candidates: ["utf8"], default: .string("utf8"))

            case .of:
                return Parameter(type: .bytes)
            }
        }
    }

    // MARK: - Property
    private let encoding = Encoding("decoded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try encoding.named(question[.encoding])

        guard let bytes = question.receiver?.bytes else { return nil }

        guard let text = encoding.text(of: bytes) else {
            throw ExecutionError("the bytes are not utf8 text")
        }

        return .string(text)
    }

    // MARK: - Private
}
