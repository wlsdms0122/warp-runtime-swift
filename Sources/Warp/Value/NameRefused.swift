//
//  NameRefused.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// A spelling that cannot be a name.
//
// Raised by the one door names come through, so the sentence says what the
// spelling was rather than where it was met — the side that met it says that,
// by placing this or by refusing in its own words.
public struct NameRefused: WarpError {
    // MARK: - Property
    public let message: String

    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place? = nil) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> NameRefused {
        NameRefused(message, at: place)
    }

    // MARK: - Private
}
