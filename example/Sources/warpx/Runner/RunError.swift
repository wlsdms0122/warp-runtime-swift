//
//  RunError.swift
//  warpx
//

import Foundation

struct RunError: Error, CustomStringConvertible {
    // MARK: - Property
    let description: String

    // MARK: - Initializer
    init(_ description: String) {
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
