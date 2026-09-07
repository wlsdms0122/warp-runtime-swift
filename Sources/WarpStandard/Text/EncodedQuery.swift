//
//  EncodedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// Text written out as bytes in a named encoding. This cannot refuse the text
// itself: a string is Unicode text, and UTF-8 spells all of it.
struct EncodedQuery: Query {
    // What this takes: the text, and the encoding to write it in.
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
                return Parameter(type: .string, oneOf: ["utf8"], default: .string("utf8"))

            case .of:
                return Parameter(type: .string)
            }
        }
    }

    // MARK: - Property
    private let encoding = Encoding("encoded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        try encoding.named(question[.encoding])

        guard case let .string(text) = question.receiver else { return nil }

        return .bytes(Array(text.utf8))
    }

    // MARK: - Private
}
