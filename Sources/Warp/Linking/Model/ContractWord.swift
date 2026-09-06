//
//  ContractWord.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// One word of one contract, under the spelling a call writes to reach it: the
// contract's own name and the word's, with a dot between them.
//
// A call that writes it names no declaration. What answers it is decided by
// the value it is sent to, which is why it is gathered apart from the symbols:
// everything in that table is one declaration, and this is a table of them.
struct ContractWord: Sendable {
    // MARK: - Property
    let contract: Name
    let word: Name

    // What the contract said the word takes and answers. No receiver: the
    // receiver is whatever satisfies the contract, which is the whole reason
    // the word is in one.
    let signature: Signature

    // The same declaration as the run reads it, lowered once here. A word in
    // a contract declares no row, so this is the only place its lowering
    // could live.
    let slots: [Slot]
    let answers: Shape?

    // Which declaration answers this word, by the name of the type that
    // answers it. The link filled this in for every type it found, so a call
    // reads a row out of it rather than resolving anything.
    let answering: [Name: Name]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
