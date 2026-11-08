//
//  Refusal.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation

// Where a case was refused: the stage, and the error that stopped it there.
struct Refusal: Sendable {
    // MARK: - Property
    let stage: Case.Stage
    let error: any Error

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
