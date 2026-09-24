//
//  Interpolation.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// What a template lowers to, for a notation that offers one.
//
// A template is written under `format` and `with`, in a notation that offers
// one. Which procedures it spends is the notation's answer: a template asks
// each piece how it reads and writes the pieces one after another.
//
// Qualified names are what these should be, though nothing here checks it. A
// name is its declared spelling: `std.text.text` names one declaration wherever
// a template is written, and a document declaring a `text` of its own declares
// a different name. Two modules claiming one spelling is a refused link
// instead of a silent winner.
public struct Interpolation: Sendable, Equatable {
    // MARK: - Property
    // The keys a template is written under.
    public static let keys: Set<Name> = ["format", "with"]

    // What every piece is asked, so that a value of any kind arrives as text.
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
