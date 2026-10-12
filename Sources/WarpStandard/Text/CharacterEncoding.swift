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
    // The encoding a procedure was handed by name, or why the name is none
    // this has, in the words both procedures that read one refuse in.
    init(_ written: Value, for procedure: String) throws {
        guard case let .string(name) = written else {
            throw ExecutionError("\(procedure) asks the name of an encoding")
        }

        guard let encoding = CharacterEncoding(rawValue: name) else {
            throw ExecutionError(
                "\(procedure) asks the name of an encoding it has (\(Self.names.joined(separator: ", "))),"
                    + " and '\(name)' is not one"
            )
        }

        self = encoding
    }

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
    // bridge: which bytes are text is this language's judgement, and it must
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
