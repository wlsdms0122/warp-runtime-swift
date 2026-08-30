//
//  Interpolation.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation

// What a template lowers to, for a notation that offers one.
//
// The keys `format` and `with` are reserved in every notation — that much is the
// document's, and the specification names those two and no others. Which words
// they spend is not: a template asks each piece how it reads and writes the
// pieces one after another, and what those two words are called is the
// notation's own answer.
//
// Qualified names are what these should be, though nothing here checks it. A
// name the author did not write must not be found by searching: an unqualified
// selector resolves against the calling module first, so a document that
// happened to declare `text` would quietly take over its own templates — a break
// with no visible cause, since the two share no letters. A qualified name is
// matched rather than searched, and two modules claiming it is a refused link
// instead of a silent winner.
public struct Interpolation: Sendable, Equatable {
    // MARK: - Property
    // What every piece is asked, so that a value of any kind arrives as text.
    public let read: String

    // What puts the pieces together.
    public let joined: String

    // MARK: - Initializer
    public init(read: String, joined: String) {
        self.read = read
        self.joined = joined
    }

    // MARK: - Public
    // MARK: - Private
}
