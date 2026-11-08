//
//  PathSyntaxError.swift
//  WarpSyntax
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

struct PathSyntaxError: WarpError {
    // MARK: - Property
    let message: String

    // MARK: - Initializer
    init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
