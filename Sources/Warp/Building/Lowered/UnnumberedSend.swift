//
//  UnnumberedSend.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// Why a native's declared sends do not stand as the numbers a document gives
// them. The rule is the numbering's; what a caller calls a native breaking it
// is the caller's to say.
enum UnnumberedSend: Error {
    // The places the sends stand at, which are not one send to a place from
    // the first.
    case misplaced([Int])

    // A spelling the document numbers nowhere.
    case unnumbered(Name)
}
