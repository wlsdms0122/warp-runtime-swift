//
//  ExpressionFormError.swift
//  WarpSyntax
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// A malformed expression form, refused where a value is read as an expression.
//
// It carries no place: an expression is spelled everywhere and this grammar is
// walked with the value alone, so where in the document it was is the reading's
// to say. The reader that asked puts its own address on before it leaves.
public struct ExpressionFormError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
