//
//  Interpolation.swift
//  WarpSyntax
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Warp

// What a template lowers to, for a notation that offers one.
//
// A template is written under `format` and `with`, in a notation that offers
// one. Which procedures it spends is the notation's answer: a template asks
// each piece how it reads and writes the pieces one after another.
//
// A name is its declared spelling: `Standard.Text.text` names one declaration
// wherever a template is written, and a document declaring a `text` of its own
// declares a different name.
public struct Interpolation: Sendable, Equatable {
    // MARK: - Property
    // The keys a template is written under: the text, and what its
    // placeholders are bound to.
    static let formatKey: Name = "format"
    static let withKey: Name = "with"
    public static let keys: Set<Name> = [formatKey, withKey]

    // What every piece is asked, so that a value of any type arrives as text.
    public let read: Name

    // What puts the pieces together, handed the pieces and the empty text
    // to write between them.
    public let joined: Name

    // MARK: - Initializer
    public init(read: Name, joined: Name) {
        self.read = read
        self.joined = joined
    }

    // MARK: - Public
    // MARK: - Private
}
