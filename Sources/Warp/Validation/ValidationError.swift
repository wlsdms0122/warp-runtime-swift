//
//  ValidationError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct ValidationError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    // MARK: - Private
}
