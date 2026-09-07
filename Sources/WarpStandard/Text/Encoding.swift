//
//  Encoding.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// The named mapping between bytes and text. The declaration's `oneOf` says the
// same names early, and this keeps its own contract too, so a name added there
// without a mapping here refuses instead of quietly answering in the wrong
// encoding.
struct Encoding: Sendable {
    // MARK: - Property
    private let word: String

    // MARK: - Initializer
    init(_ word: String) {
        self.word = word
    }

    // MARK: - Public
    // Refuses a name this has no mapping for, before either direction runs.
    func named(_ value: Value) throws {
        guard case let .string(name) = value else {
            throw ExecutionError("\(word) asks \(value.type) for an encoding name")
        }

        guard name == "utf8" else {
            throw ExecutionError("\(word) has no encoding named '\(name)'")
        }
    }

    // Validated by the standard library's own UTF-8, not a platform string
    // bridge: which bytes are text is this language's judgment, and it must
    // land the same on every host. A broken sequence answers nil, never a
    // completed guess.
    func text(of bytes: [UInt8]) -> String? {
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

    // MARK: - Private
}
