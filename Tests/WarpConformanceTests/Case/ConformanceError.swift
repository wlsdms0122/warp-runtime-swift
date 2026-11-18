//
//  ConformanceError.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation

struct ConformanceError: Error, CustomStringConvertible {
    // MARK: - Property
    let description: String

    // MARK: - Initializer
    init(_ description: String) {
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
