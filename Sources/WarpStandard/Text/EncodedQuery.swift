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
    func validate(_ question: Question<Self>) throws {
        if let refusal = CharacterEncoding.refusal(naming: question[.encoding], for: "Standard.Text.encoded") {
            throw ValidationError(refusal, at: nil)
        }
    }

    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("Standard.Text.encoded asks a String")
        }

        guard case let .string(name) = question[.encoding], let encoding = CharacterEncoding(rawValue: name) else {
            throw ExecutionError(
                CharacterEncoding.refusal(naming: question[.encoding], for: "Standard.Text.encoded")
                    ?? "Standard.Text.encoded asks the name of an encoding"
            )
        }

        return .bytes(encoding.bytes(of: text))
    }

    // MARK: - Private
}
