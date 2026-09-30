//
//  WritingError.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// A piece of a program this notation cannot write.
public struct WritingError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
