//
//  Datum.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// One element of a text: an atom, or a list of elements in parentheses. This
// is all a text is before anything in it is known to mean, so its reading
// and its writing know nothing of what a tree holds.
struct Datum: Sendable {
    indirect enum Form: Sendable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case text(String)
        case bytes([UInt8])
        case name(String)
        case list([Datum])
    }

    // MARK: - Property
    let form: Form

    // Where it began, counted in scalars from the start of the text it was
    // read from. Nil for one made to be written.
    let offset: Int?

    // Whether a list is written with each of its parts on a line of its own
    // once it holds a list. Said by whoever made it, since where a list
    // stands decides it and a list does not know where it stands.
    let isBlock: Bool

    var isList: Bool {
        guard case .list = form else { return false }

        return true
    }

    // The word a list begins with, nil for an atom or a list led by none.
    var word: String? {
        guard case let .list(elements) = form, case let .name(word)? = elements.first?.form else { return nil }

        return word
    }

    // MARK: - Initializer
    init(_ form: Form, at offset: Int? = nil, isBlock: Bool = false) {
        self.form = form
        self.offset = offset
        self.isBlock = isBlock
    }

    // MARK: - Public
    static func name(_ name: String) -> Datum {
        Datum(.name(name))
    }

    // A list led by a word, written on one line.
    static func node(_ word: String, _ operands: [Datum] = []) -> Datum {
        Datum(.list([.name(word)] + operands))
    }

    // A list led by a word, its parts written a line each.
    static func block(_ word: String, _ operands: [Datum] = []) -> Datum {
        Datum(.list([.name(word)] + operands), isBlock: true)
    }

    // MARK: - Private
}
