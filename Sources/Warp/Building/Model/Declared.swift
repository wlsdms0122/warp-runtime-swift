//
//  Declared.swift
//  Warp
//
//  Created by JSilver on 9/21/26.
//

import Foundation

// What a declaration says of itself that another document reads: what it
// takes and answers, and who may name it. One entry of the space a link
// resolves spellings in.
struct Declared: Sendable {
    // MARK: - Property
    let signature: Signature
    let access: Access

    // MARK: - Initializer
    init(signature: Signature, access: Access) {
        self.signature = signature
        self.access = access
    }

    // MARK: - Public
    // MARK: - Private
}
