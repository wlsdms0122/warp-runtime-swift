//
//  ParameterOccurrence.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// One mention of a type parameter in a signature: the name, and the
// constraint names that mention carries.
public struct ParameterOccurrence: Sendable, Equatable {
    // MARK: - Property
    public let name: Name
    public let constraints: [Name]

    // MARK: - Initializer
    public init(name: Name, constraints: [Name]) {
        self.name = name
        self.constraints = constraints
    }

    // MARK: - Public
    // MARK: - Private
}
