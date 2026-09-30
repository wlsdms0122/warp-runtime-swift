//
//  ObjectRefused.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// An object handed back that is not one: a field missing, a tag no writing
// gives, a number where a name was written, or parts that each read and do not
// stand to each other.
//
// Only that way. A document that cannot be one answers no writing at all,
// which is a property of the document rather than something that went wrong.
//
// An object is what a build wrote, so nothing here is an author's mistake.
// What it says is which part of the writing did not read, so a caller holding a cache knows to build again
// rather than to go looking at a document.
//
// Beside `BuildError` rather than beside the writing, because what it is about
// is an object and an object is what a build makes. Which notation it was
// laid down in is the writing's business and not this.
public struct ObjectRefused: WarpError {
    // MARK: - Property
    public let message: String

    // Nothing, and never anything. A place is an address in a document, and
    // what is refused here is an object's bytes: there is no text for a reader
    // to be pointed back into.
    public let place: Place? = nil

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
