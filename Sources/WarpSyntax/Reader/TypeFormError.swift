//
//  TypeFormError.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A type spelled in a way this notation cannot read. About the writing, not
// about the language. Whether the type it names exists is a link question.
struct TypeFormError: WarpError {
    // MARK: - Property
    let message: String

    // MARK: - Initializer
    init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
