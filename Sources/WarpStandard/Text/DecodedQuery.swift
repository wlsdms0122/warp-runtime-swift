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
                return Parameter(name: "bytes", type: .array(.int))

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
        guard let bytes = question[.bytes].bytes else {
            throw ExecutionError(Self.refusal(bytes: question[.bytes]) ?? "Standard.Text.decoded asks an Array<Int>")
        }

        let encoding = try CharacterEncoding(question[.encoding], for: "Standard.Text.decoded")

        guard let text = encoding.text(of: bytes) else {
            throw ExecutionError("Standard.Text.decoded asks an Array<Int> that is text in the encoding named")
        }

        return .string(text)
    }

    // MARK: - Private
    // Why a list is no bytes, naming the first element that is not a whole
    // number from 0 to 255, and nothing where every element is one.
    private static func refusal(bytes written: Value) -> String? {
        guard case let .array(elements) = written else { return nil }

        for (position, element) in elements.enumerated() {
            guard case let .int(number) = element, UInt8(exactly: number) != nil else {
                return "Standard.Text.decoded asks an Array<Int> of bytes, and [\(position)] is"
                    + " \(Rendering(element).text()), which is no whole number from 0 to 255"
            }
        }

        return nil
    }
}
