//
//  Activation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One body running: its slots, and what each slot was called, for a refusal
// that names one. The cells are a value, so a closure or a concurrent piece
// takes its own; the holds among them share their boxes.
struct Activation: Sendable {
    // MARK: - Property
    var cells: [Cell]
    let names: [String]

    // MARK: - Initializer
    init(cells: [Cell], names: [String]) {
        self.cells = cells
        self.names = names
    }

    init(_ layout: Layout) {
        self.cells = Array(repeating: .value(.null), count: layout.size)
        self.names = layout.names
    }

    // MARK: - Public
    // MARK: - Private
}
