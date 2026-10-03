//
//  AnswerProof.swift
//  Warp
//
//  Created by JSilver on 10/3/26.
//

import Foundation

// What one body proves of its answers: nothing, or that they hold once the
// declarations of its own document it leans on hold, none where it proves
// them alone. Settled over the whole document, since a declaration it leans
// on may be read after it.
enum AnswerProof: Sendable {
    case broken
    case holds(leaning: Set<Name>)
}
