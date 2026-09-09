//
//  Gathered.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// What the whole list of documents says, read once and handed to a compile:
// the order the documents stand in, and every declaration they make, in the
// word space and the three shape spaces.
//
// No document makes any of these readings about itself, and the refusals that
// go with them are made where they are read. One document handed over twice,
// one spelling declared by two of them, one name standing for two of a shape,
// a membership and a contract, and a ring.
struct Gathered {
    // MARK: - Property
    // Where each document stands in the list it was given in, in the order
    // each one's needs stand before it.
    let standing: [Int]

    // Every declaration in the word space, under the spelling it was declared
    // by.
    let symbols: [Symbol]

    // Every shape the list declared, lowered, with which types answer which
    // contracts worked out. Every judgment a compile makes is asked of this.
    let types: TypeTable

    // The words the contracts ask, under the spellings a call writes to reach
    // them.
    let contractWords: [Name: ContractWord]

    // The declarations that answer some contract's word. A path steps to a
    // word by its last segment, and which of these a segment means is the
    // contract's pick rather than a name's, so no path reaches one.
    let answering: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
