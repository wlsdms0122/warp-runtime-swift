//
//  Unplaced.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// What the text's two layers refuse with, reading a text or writing one. It
// knows where in the text it happened and not yet how to say it: the line and
// column are worked out once, where the text is read, from the whole text,
// and the encoding says the refusal at its door. Nil where what is refused
// was never read from a text.
struct Unplaced: Error {
    // MARK: - Property
    let said: String
    let offset: Int?

    // MARK: - Initializer
    init(_ said: String, at offset: Int? = nil) {
        self.said = said
        self.offset = offset
    }

    // MARK: - Public
    // MARK: - Private
}
