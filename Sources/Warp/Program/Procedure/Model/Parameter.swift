//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// One parameter of a declaration: the name its body reads it by, what it
// takes, and what it says of itself to a reader. The name is the
// declaration's; a procedure type carries none.
public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    public let name: Name

    // What this takes. A document writing no type for it says `Any`.
    public let type: TypeExpression
    public let description: String?

    // MARK: - Initializer
    public init(
        name: Name,
        type: TypeExpression = .any,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
