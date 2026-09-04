//
//  Activation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One body running: its slots, and the layout that says what each slot was
// called, for a refusal that names one. The cells are a value, so a closure
// or a concurrent piece takes its own; the holds among them share their
// boxes.
struct Activation: Sendable {
    // MARK: - Property
    var cells: [Cell]
    let layout: Frame

    // MARK: - Initializer
    init(_ layout: Frame) {
        self.cells = Array(repeating: .value(.null), count: layout.size)
        self.layout = layout
    }

    init(cells: [Cell], layout: Frame) {
        self.cells = cells
        self.layout = layout
    }

    // MARK: - Public
    // MARK: - Private
}
