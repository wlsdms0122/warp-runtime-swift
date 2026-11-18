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
    // ones the slot's type marks `inout`.
    case apply(inPlace: [Int])

    // A reference: the path it reads, as the walk that judged it placed it.
    case reference(LoweredPath)

    // A call: what fills each type parameter its callee names, by label,
    // `Self` among them for a call through a contract.
    case call(filling: [Name: LoweredType])

    // A cast: the type it names, read under what the procedure it is
    // written in holds its type parameters to.
    case cast(LoweredType)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
