//
//  CharacterEncoding.swift
//  WarpStandard
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Warp

// The named mapping between bytes and text, in both directions. A case is a
// name a declaration offers and the mapping it names.
enum CharacterEncoding: String, CaseIterable, Sendable {
    case utf8

    // MARK: - Property
    static var names: [String] { allCases.map(\.rawValue) }

    // MARK: - Initializer
    // MARK: - Public
    func bytes(of text: String) -> [UInt8] {
        switch self {
        case .utf8:
            return Array(text.utf8)
        }
    }

    // A broken sequence answers nil, never a completed guess.
    func text(of bytes: [UInt8]) -> String? {
        switch self {
        case .utf8:
            return utf8Text(of: bytes)
        }
    }

    // MARK: - Private
    // Validated by the standard library's own UTF-8, not a platform string
    // bridge: which bytes are text is this language's judgment, and it must
    // land the same on every host.
    private func utf8Text(of bytes: [UInt8]) -> String? {
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
