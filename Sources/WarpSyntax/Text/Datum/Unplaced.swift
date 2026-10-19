//
//  Unplaced.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// A refusal of a text that knows where it happened and not yet how to say it.
// The line and column are worked out once, where the text is read, from the
// whole text. Nil where what is refused was never read from a text.
struct Unplaced: Error {
    // MARK: - Property
    let said: String
    let offset: Int?

    // MARK: - Initializer
    init(_ said: String, at offset: Int?) {
        self.said = said
        self.offset = offset
    }

    // MARK: - Public
    // MARK: - Private
}
