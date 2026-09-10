//
//  Reference.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// One thing a link resolves to a declarer.
//
// A document declares some of these and leans on others, and the same question
// is asked of every one: which document in this list declares it. That the
// answer was looked up in a different table depending on what kind of thing it
// was is a fact about the tables, not about the things, and a caller gathering
// needs had to know which table each need belonged to.
//
// The kind rides on the case rather than being dropped, so a word and a shape
// spelled alike stay two references. A link refuses a name standing for a
// shape and a membership at once and says nothing about a word spelled like a
// type, and that difference survives one table.
enum Reference: Hashable, Sendable, Comparable {
    case word(Name)
    case shape(Name)

    // MARK: - Internal
    // The name itself, for the tables and sentences that want it without the
    // kind.
    var name: Name {
        switch self {
        case let .word(name), let .shape(name): name
        }
    }

    // What a sentence calls this kind where it names one.
    var spelled: String {
        switch self {
        case .word: "word"
        case .shape: "shape"
        }
    }

}
