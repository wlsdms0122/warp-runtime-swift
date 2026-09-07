//
//  CatalogueError.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What a catalogue refuses. Only one thing: a name it cannot answer for,
// because two of the modules in it declare that name and nothing says which
// one a link asking for it meant.
public struct CatalogueError: WarpError {
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
        CatalogueError(message, at: place)
    }

    // MARK: - Private
}
