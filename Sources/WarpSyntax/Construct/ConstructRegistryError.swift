//
//  ConstructRegistryError.swift
//  WarpSyntax
//
//  Created by JSilver on 10/10/26.
//

import Foundation
import Warp

// A keyword table a host assembled that no notation can read by: a key that
// is no name, claimed twice, or one a document writes for something else.
// The host's mistake, so it names no place in a document.
public struct ConstructRegistryError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
