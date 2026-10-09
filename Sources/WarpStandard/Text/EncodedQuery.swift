//
//  EncodedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// Text written out as bytes in a named encoding. This cannot refuse the text
// itself.
struct EncodedQuery: Query {
    // What this takes: the text, and the encoding to write it in.
    enum Parameters: Int, ParameterSet {
        case text
        case encoding

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .text:
                return Parameter(name: "text", type: .string)

            case .encoding:
                return Parameter(name: "encoding", type: .string)
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
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("Standard.Text.encoded asks a String")
        }

        let encoding = try CharacterEncoding(question[.encoding], for: "Standard.Text.encoded")

        return .bytes(encoding.bytes(of: text))
    }

    // MARK: - Private
}
