//
//  ModuleGraphError.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What standing a module graph up refuses. Only one thing: modules that need
// each other, which have no order to be compiled in.
//
// The place is the document the cycle was closed on, and the sentence names
// every step of the cycle.
public struct ModuleGraphError: WarpError {
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
        ModuleGraphError(message, at: place)
    }

    // MARK: - Private
}
