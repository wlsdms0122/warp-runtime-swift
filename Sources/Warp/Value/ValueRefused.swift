//
//  ValueRefused.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A value that cannot be made: fields that do not fill the layout they are
// handed to, or one name written twice.
//
// Raised by the doors values come through from outside a run, so the sentence
// says what was wrong with the value rather than where it was met.
public struct ValueRefused: WarpError {
    // MARK: - Property
    public let message: String

    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place? = nil) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> ValueRefused {
        ValueRefused(message, at: place)
    }

    // MARK: - Private
}
