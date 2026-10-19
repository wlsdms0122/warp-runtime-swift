//
//  Declared.swift
//  Warp
//
//  Created by JSilver on 9/21/26.
//

import Foundation

// What a declaration says of itself that another document reads: everything
// a call may expect of it, and who may name it. One entry of the space a link
// resolves spellings in.
struct Declared: Sendable {
    // MARK: - Property
    let signature: Signature
    let access: Access

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
