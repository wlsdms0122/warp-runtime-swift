//
//  Frame.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// How a body's frame is laid out: how many slots, which of them the
// parameters fill in parameter order, which module variables it reads and
// where, which slots a closure fills from what it took with it, and what
// each slot was called, for a refusal that names it.
struct Frame: Sendable {
    // MARK: - Property
    let size: Int
    let parameters: [Int]
    let variables: [(variable: Int, slot: Int)]
    let captures: [Int]
    let names: [Name]

    // MARK: - Initializer
    init(size: Int, parameters: [Int], variables: [(variable: Int, slot: Int)], captures: [Int], names: [Name]) {
        self.size = size
        self.parameters = parameters
        self.variables = variables
        self.captures = captures
        self.names = names
    }

    // MARK: - Public
    // MARK: - Private
}
