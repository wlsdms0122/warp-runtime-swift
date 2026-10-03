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
    // ones the slot's type marks `inout`, and what its answer is judged
    // against where the slot's type writes `returns`.
    case apply(inPlace: [Int], against: LoweredType?)

    // A call whose callee settles a wider answer than the call reads: what
    // the answer is judged against where the call stands.
    case call(against: LoweredType)

    // A closure literal: what its row carries that the literal does not
    // write, derived from its body.
    case closure(constness: Constness, isolation: Isolation, failing: Failing)
}
