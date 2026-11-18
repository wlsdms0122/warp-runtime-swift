//
//  EncodingRefused.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// What an encoding refuses with: bytes or a text that are no document, or a
// value no document carries.
public struct EncodingRefused: WarpError {
    // Where in a text the reader stood, both counted from one, the column in
    // scalars.
    public struct Position: Sendable, Equatable {
        // MARK: - Property
        public let line: Int
        public let column: Int

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    public let message: String

    // Nil for bytes and for a value being written, which stand at no line.
    public let position: Position?

    public var description: String {
        guard let position else { return message }

        return "\(message), at line \(position.line) column \(position.column)"
    }

    // MARK: - Initializer
    init(_ message: String, at position: Position? = nil) {
        self.message = message
        self.position = position
    }

    // MARK: - Public
    // MARK: - Private
}
