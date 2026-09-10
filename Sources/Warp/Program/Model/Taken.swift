//
//  Taken.swift
//  Warp
//

import Foundation

// One of the parameters a declaration takes, beside the name it stands under.
// A parameter says what it asks for and nothing about what it is called, since
// a declaration calls it by the key it wrote it under.
//
// `Slot` is the same parameter as the run reads it, with the type lowered
// against a table.
public struct Taken: Sendable, Equatable {
    // MARK: - Property
    public let name: Name
    public let parameter: Parameter

    // MARK: - Initializer
    public init(name: Name, parameter: Parameter) {
        self.name = name
        self.parameter = parameter
    }

    // MARK: - Public
    // MARK: - Private
}
