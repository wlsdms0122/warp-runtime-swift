//
//  Refusal.swift
//  warpx
//

import Foundation

// Where a program was refused: the stage, and the error that stopped it there.
struct Refusal: Error, CustomStringConvertible {
    enum Stage: String {
        case load
        case build
        case run
    }

    // MARK: - Property
    let stage: Stage
    let error: any Error

    var description: String {
        "refused at the \(stage.rawValue) (\(type(of: error))): \(error)"
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
