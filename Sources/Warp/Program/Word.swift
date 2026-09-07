//
//  Word.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// A procedure implemented natively rather than written as a body. What every
// one of them says about itself, whichever door it answers through.
//
// The parameters are here because they are the word's own: the names it
// declares are the names its body reads, and one type saying both is what
// keeps a word from reading a name it never declared.
public protocol Word: Sendable {
    associatedtype Parameters: ParameterSet

    // Whether this touches no name another body could touch at the same time.
    // A word holding state between calls says false, and the link stops
    // deriving isolation through it and through whatever calls it.
    var isolated: Bool { get }

    // What may come out of this when the work goes wrong, by the words its
    // failures name themselves. A word that only ever throws at an author
    // mistake fails nothing, which is the default, so a word that can fail
    // says so and one that could fail anything says `unstated`.
    var failing: Failing { get }
}

public extension Word {
    var isolated: Bool { true }

    var failing: Failing { .these([]) }
}
