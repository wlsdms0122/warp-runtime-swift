//
//  ArtifactRefused.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// An artifact handed back that is not one: a field missing, a tag no writing
// gives, a number where a name was written, or parts that each read and do not
// stand to each other.
//
// Only that way. A document that cannot be one answers no writing at all,
// which is a property of the document rather than something that went wrong.
//
// An artifact is this runtime's own writing read back by this runtime, so
// nothing here is an author's mistake. What it says is which part of the
// writing did not read, so a caller holding a cache knows to build again
// rather than to go looking at a document.
//
// Beside `BuildError` rather than beside the writing, because what it is about
// is an artifact and an artifact is what a build makes. Which notation it was
// laid down in is the writing's business and not this.
public struct ArtifactRefused: WarpError {
    // MARK: - Property
    public let message: String

    // Nothing, and never anything. A place is an address in a document, and
    // what is refused here is bytes this runtime wrote: there is no text for
    // a reader to be pointed back into, so a door that took one would promise
    // what it cannot hold.
    public let place: Place? = nil

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
