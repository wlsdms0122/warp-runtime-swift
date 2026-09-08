//
//  WorldError.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What standing a world up refuses. Only one thing: modules that need each
// other, which have no order to be compiled in.
//
// The place is the declaration the cycle was closed on, so the sentence names
// a step of the ring rather than the ring as a whole.
public struct WorldError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> Self {
        WorldError(message, at: place)
    }

    // MARK: - Private
}
