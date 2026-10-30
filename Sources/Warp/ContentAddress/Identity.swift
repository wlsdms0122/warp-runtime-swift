//
//  Identity.swift
//  Warp
//
//  Created by JSilver on 8/31/26.
//

import Foundation

// Which document this is, worked out from what it says rather than from what it
// is called: the digest of its canonical bytes. Derived and never declared, so
// two hosts holding the same document work out the same digest without
// having agreed on anything but the language.
//
// Deriving it is `WarpSyntax`'s. This type is here so that a place can carry
// one without the language learning how bytes are written.
public struct Identity: ContentAddress {
    // MARK: - Property
    public let bytes: [UInt8]

    // MARK: - Initializer
    // Open to every caller, because what derives one reads bytes and that is
    // another package's. The one place an identity arrives written down is the
    // reading of an object, which is handed the identity the object was kept
    // under and refuses any other.
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    // MARK: - Public
    // MARK: - Private
}
