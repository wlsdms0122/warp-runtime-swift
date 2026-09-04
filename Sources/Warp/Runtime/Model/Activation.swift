//
//  Activation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One body running: its slots, and the frame that says what each slot was
// called, for a refusal that names one. The cells are a value, so a closure
// or a concurrent piece takes its own; the holds among them share their
// boxes.
struct Activation: Sendable {
    // MARK: - Property
    var cells: [Cell]
    let frame: Frame

    // MARK: - Initializer
    init(_ frame: Frame) {
        self.cells = Array(repeating: .value(.null), count: frame.size)
        self.frame = frame
    }

    init(cells: [Cell], frame: Frame) {
        self.cells = cells
        self.frame = frame
    }

    // MARK: - Public
    // MARK: - Private
}
