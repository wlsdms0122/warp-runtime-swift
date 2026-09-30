//
//  Encoding.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// The named mapping between bytes and text, in both directions.
struct Encoding: Sendable {
    // MARK: - Property
    // The names a declaration offers, which are the mappings this writes.
    static let names = ["utf8"]

    // MARK: - Initializer
    // MARK: - Public
    // A string is Unicode text, and UTF-8 spells all of it.
    func bytes(of text: String) -> [UInt8] {
        Array(text.utf8)
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
