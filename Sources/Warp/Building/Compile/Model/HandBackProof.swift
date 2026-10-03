//
//  HandBackProof.swift
//  Warp
//
//  Created by JSilver on 10/3/26.
//

import Foundation

// What one body proves of what it hands back, its answer and every variable
// handed to it in place: nothing, or that it holds once the declarations of
// its own document it leans on hold, none where it proves it alone. Settled
// over the whole document, since a declaration it leans on may be read after
// it.
enum HandBackProof: Sendable {
    case broken
    case holds(leaning: Set<Name>)
}
