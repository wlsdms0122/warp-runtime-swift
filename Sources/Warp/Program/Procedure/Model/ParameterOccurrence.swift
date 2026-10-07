//
//  ParameterOccurrence.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// One mention of a type parameter in a signature: the name, and the
// contracts that mention bounds it by.
public struct ParameterOccurrence: Sendable, Equatable {
    // MARK: - Property
    public let name: Name
    public let bounds: [Name]

    // MARK: - Initializer
    public init(name: Name, bounds: [Name]) {
        self.name = name
        self.bounds = bounds
    }

    // MARK: - Public
    // MARK: - Private
}
