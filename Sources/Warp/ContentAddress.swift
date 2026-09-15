//
//  ContentAddress.swift
//  Warp
//
//  Created by JSilver on 9/16/26.
//

import Foundation

// A value that says what something is by what it holds, rather than by what it
// is called.
//
// What the types under this answer differ: one says which document a document
// is, another says which artifact an artifact is. They stay apart so that
// neither can be handed to the other's door. What does not differ is how the
// bytes read where a person sees them, and writing that rule twice is how two
// of them end up reading differently.
public protocol ContentAddress: Sendable, Equatable, Hashable, CustomStringConvertible {
    var bytes: [UInt8] { get }

    init(_ bytes: [UInt8])
}

public extension ContentAddress {
    // The first few bytes, the way every content-addressed thing is quoted in
    // prose. Enough to tell two apart by eye and never enough to be mistaken
    // for the whole.
    var short: String {
        String(rendered.prefix(12))
    }

    var rendered: String {
        bytes.map { byte in String(format: "%02x", byte) }.joined()
    }

    var description: String {
        short
    }
}
