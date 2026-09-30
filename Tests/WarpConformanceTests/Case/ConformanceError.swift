//
//  ConformanceError.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

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
