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

    // Which document the running body came from. The numbers the body carries
    // are that document's, so this is what a call reads them against.
    let origin: Int

    // MARK: - Initializer
    init(_ frame: Frame, of origin: Int) {
        self.cells = Array(repeating: .value(.null), count: frame.size)
        self.frame = frame
        self.origin = origin
    }

    // MARK: - Public
    // MARK: - Private
}
