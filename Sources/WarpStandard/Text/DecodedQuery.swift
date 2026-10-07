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
        case bytes
        case encoding

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .bytes:
                return Parameter(name: "bytes", type: .bytes)

            case .encoding:
                return Parameter(
                    name: "encoding",
                    type: .string,
                    candidates: CharacterEncoding.names
                )
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard let bytes = question[.bytes].bytes else {
            throw ExecutionError("Standard.Text.decoded asks bytes")
        }

        guard
            case let .string(name) = question[.encoding],
            let encoding = CharacterEncoding(rawValue: name)
        else {
            throw ExecutionError("Standard.Text.decoded asks the name of an encoding it has")
        }

        guard let text = encoding.text(of: bytes) else {
            throw ExecutionError("Standard.Text.decoded asks bytes that are text in the encoding named")
        }

        return .string(text)
    }

    // MARK: - Private
}
