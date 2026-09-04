//
//  Linkage.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// Which link a row belongs to.
//
// A row's numbers are addresses into the tables one link built: which shape a
// slot settles against, which procedure a send reaches, which document's
// variables a body reads. Nothing holds all three, so what says a row is at
// home is the link that made them.
//
// Identity and nothing else, the way an address is. Two links declaring the
// same shapes are still two links, and a body carried out of one is read by
// neither the other's rows nor its own numbers.
final class Linkage: Sendable {
    // MARK: - Property
    // No link at all: what the table a judge is handed carries when the
    // caller named none. Nothing is at home in it, which is the answer a
    // judge asked without a link is owed.
    static let none = Linkage()

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
