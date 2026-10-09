//
//  Judgement.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged about one expression that its text does not
// write, for lowering to read where it lowers that expression and for the
// hand-back proof to read over the body.
enum Judgement: Sendable {
    // A call of a value: the positions it hands a variable in place, the
    // ones the slot's type marks `inout`, and what it is judged on where it
    // stands, nil where nothing: its answer where the slot's type writes
    // `returns`, and each variable handed in place. The run judges the
    // answer only where the `returns` of the closure it reaches is not one
    // the call reads as it stands, and a variable only where that closure
    // names a type parameter at the slot, since a closure written with a type
    // there settles every write to it.
    case apply(inPlace: [Int], judging: CallJudgement?)

    // A call whose answer is read as what filled the callee's type
    // parameter, or answered by the row a contract's procedure picks, or
    // which hands back in place what the callee holds as its own type
    // parameter: what it is judged on where it stands.
    case call(CallJudgement)

    // A closure literal: what its row carries that the literal does not
    // write, derived from its body.
    case closure(constness: Constness, isolation: Isolation, failing: Failing)
}
