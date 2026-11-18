//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// One parameter of a declaration: the name its body reads it by and what it
// takes. The name is the declaration's; a procedure type carries none.
public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    public let name: Name

    // What this takes. A document writing no type for it says `Any`.
    public let type: TypeExpression

    // MARK: - Initializer
    public init(name: Name, type: TypeExpression = .any) {
        self.name = name
        self.type = type
    }

    // MARK: - Public
    // MARK: - Private
}
