//
//  WrittenRow.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// A row as an object writes it, before it stands under a spelling: a declared
// row writes its own, and a lifted row is handed the one its numbering
// answers.
struct WrittenRow {
    // MARK: - Property
    let signature: Signature
    let access: Access
    let implementation: Judged.Implementation

    // MARK: - Initializer
    // MARK: - Public
    func judged(_ label: Name) throws -> Judged {
        try Judged(label: label, signature: signature, access: access, judging: implementation)
    }

    // MARK: - Private
}
