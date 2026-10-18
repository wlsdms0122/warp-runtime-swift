//
//  Judgement.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged about one expression that its text does not
// write, for lowering to read where it lowers that expression.
enum Judgement: Sendable {
    // A call of a value: the positions it hands a variable in place, the
    // ones the slot's type marks `inout`, and the type written for the value
    // called, nil where nothing was written.
    case apply(inPlace: [Int], declared: LoweredType?)

    // A reference: the path it reads, as the walk that judged it placed it.
    case reference(LoweredPath)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
