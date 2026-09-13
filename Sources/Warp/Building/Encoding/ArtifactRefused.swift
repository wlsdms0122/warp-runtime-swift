//
//  ArtifactRefused.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// Bytes handed back as an artifact that are not one: a field missing, a tag
// no writing gives, a number where a name was written.
//
// An artifact is this runtime's own writing read back by this runtime, so
// nothing here is an author's mistake. What it says is which part of the
// writing did not read, so a caller holding a cache knows to build again
// rather than to go looking at a document.
public struct ArtifactRefused: WarpError {
    // MARK: - Property
    public let message: String

    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place? = nil) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> ArtifactRefused {
        ArtifactRefused(message, at: place)
    }

    // MARK: - Private
}
