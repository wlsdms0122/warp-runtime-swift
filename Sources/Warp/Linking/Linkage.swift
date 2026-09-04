//
//  Linkage.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// Which link a row belongs to. A row's numbers are addresses into the tables
// one link built — which shape, which procedure, which document's variables —
// and nothing holds all three, so the link that made them is what says a row
// is at home.
final class Linkage: Sendable {
    // MARK: - Property
    // No link at all, for a table a caller assembled.
    static let none = Linkage()

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
