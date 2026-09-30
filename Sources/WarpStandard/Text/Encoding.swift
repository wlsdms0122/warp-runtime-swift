//
//  Encoding.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// The named mapping between bytes and text.
struct Encoding: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
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
