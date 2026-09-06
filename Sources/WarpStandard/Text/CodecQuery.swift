//
//  CodecQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// Reading bytes as text in a named encoding, and writing text back out as
// bytes. Two directions of one mapping, so one implementation with the
// direction as its data — and the encoding read here too: the declaration's
// `oneOf` says the same names early, but this keeps its own contract, so a
// name added there without a mapping here refuses instead of quietly
// answering in the wrong encoding.
//
// Decoding can refuse: bytes carry no promise of being text, and completing a
// broken sequence with replacement characters would answer a text nobody sent.
// Encoding cannot — a string is Unicode text, and UTF-8 spells all of it.
public struct CodecQuery: Query {
    public enum Direction: Sendable {
        case decoded
        case encoded
    }

    // MARK: - Property
    private let direction: Direction

    // MARK: - Initializer
    public init(_ direction: Direction) {
        self.direction = direction
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        let named = question["encoding"]

        guard case let .string(name) = named else {
            throw ExecutionError("\(direction) asks \(named.type) for an encoding name")
        }

        guard name == "utf8" else {
            throw ExecutionError("\(direction) has no encoding named '\(name)'")
        }

        switch (direction, question.receiver) {
        // Validated by the standard library's own UTF-8, not a platform
        // string bridge — which bytes are text is this language's judgment,
        // and it must land the same on every host.
        case let (.decoded, .bytes(bytes)):
            guard let text = Self.utf8(bytes) else {
                throw ExecutionError("the bytes are not \(name) text")
            }

            return .string(text)

        case let (.encoded, .string(text)):
            return .bytes(Array(text.utf8))

        default:
            return nil
        }
    }

    // MARK: - Private
    // The one decode loop, over the standard library's UTF-8 state machine —
    // a broken sequence answers nil, never a completed guess.
    private static func utf8(_ bytes: [UInt8]) -> String? {
        var text = ""
        var iterator = bytes.makeIterator()
        var decoder = UTF8()

        text.reserveCapacity(bytes.count)

        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar):
                text.unicodeScalars.append(scalar)

            case .emptyInput:
                return text

            case .error:
                return nil
            }
        }
    }
}

extension CodecQuery.Direction: CustomStringConvertible {
    public var description: String {
        switch self {
        case .decoded:
            return "decoded"

        case .encoded:
            return "encoded"
        }
    }
}
