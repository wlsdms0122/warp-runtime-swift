//
//  ObjectRefused.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// An object handed back that is not one: a field missing, a tag no writing
// gives, a number where a name was written, or parts that each read and do not
// stand to each other. What it says is which part of the writing did not
// read, so a host holding a cache knows to build again rather than to go
// looking at a document.
public struct ObjectRefused: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
