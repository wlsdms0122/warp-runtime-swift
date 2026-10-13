//
//  Leaning.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// A reading a document's body handed where a contract is asked, which the
// compile could not answer: what answers a contract is read off the claims of
// the whole link, and a claim holds for the values its head takes, so the link
// holds the reading itself to the claim about its type.
struct Leaning: Hashable, Sendable {
    // MARK: - Property
    let reading: LoweredType
    let contract: Name

    // MARK: - Initializer
    // A literal whole number is held as an Int wherever it stands, which is
    // what the link reads it as.
    init(reading: LoweredType, contract: Name) {
        self.reading = reading.asHeld
        self.contract = contract
    }

    // MARK: - Public
    // MARK: - Private
}
