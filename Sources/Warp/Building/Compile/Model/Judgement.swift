//
//  Judgement.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged about one expression that its text does not
// write, for lowering to read where it lowers that expression and for the
// answer proof to read over the body.
enum Judgement: Sendable {
    // A call of a value: the positions it hands a variable in place, the
    // ones the slot's type marks `inout`, what its answer is judged against
    // where the slot's type writes `returns`, and what each variable handed
    // in place is judged against once the call is over, in position order. The
    // run judges a variable only where the closure it reaches names a type
    // parameter at that slot, since a closure written with a type there
    // settles every write to it.
    case apply(inPlace: [Int], against: LoweredType?, handedBack: [HandedBack])

    // A call whose callee settles a wider answer than the call reads, or
    // hands back in place what it holds as its own type parameter: what the
    // answer is judged against where the call stands, nil where it needs no
    // judgement, and what each variable handed back is judged against once
    // the call is over, in position order. One of the two is there.
    case call(against: LoweredType?, handedBack: [HandedBack])

    // A closure literal: what its row carries that the literal does not
    // write, derived from its body.
    case closure(constness: Constness, isolation: Isolation, failing: Failing)
}
