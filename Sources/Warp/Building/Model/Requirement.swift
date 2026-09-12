//
//  Requirement.swift
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
struct Requirement: Sendable {
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
    let answers: LoweredType?

    // Which declaration answers this word, by the name of the type that
    // answers it. The link filled this in for every type it found, so a call
    // reads a row out of it rather than resolving anything.
    let answering: [Name: Name]

    // MARK: - Initializer
    // MARK: - Public
    // Every word every contract in these tables asks, under the spelling a
    // call writes to reach one.
    //
    // Which declaration answers a word is read off the tables rather than
    // carried from where the answers were gathered. A type answering a
    // contract answers every one of its words by a declaration named for the
    // type and the word, so the table saying which types answer says the
    // whole of it.
    static func table(in types: TypeTable) -> [Name: Requirement] {
        types.contracts.reduce(into: [Name: Requirement]()) { table, entry in
            let answering = types.loweredTypes.satisfying[entry.key] ?? []

            for (word, signature) in entry.value {
                table[spelling(of: entry.key, word: word)] = Requirement(
                    contract: entry.key,
                    word: word,
                    signature: signature,
                    slots: signature.lowered(in: types.loweredTypes),
                    answers: signature.returns?.lowered(in: types.loweredTypes),
                    answering: answering.reduce(into: [Name: Name]()) { held, type in
                        held[type] = spelling(of: type, word: word)
                    }
                )
            }
        }
    }

    // The spelling a call writes to reach a word: the name it is asked of and
    // the word's, with a dot between them. A contract's word and the
    // declaration answering it are spelled the same way, by the contract and
    // by the type.
    static func spelling(of name: Name, word: Name) -> Name {
        Name(normal: "\(name.spelling).\(word.spelling)")
    }

    // MARK: - Private
}
