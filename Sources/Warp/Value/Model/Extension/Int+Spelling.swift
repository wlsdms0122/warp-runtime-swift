//
//  Int+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/24/26.
//

import Foundation

extension Int {
    // One value, one spelling: a candidate written `+1` or `007` is a second
    // spelling of a number that already has one, so reading it back must
    // reproduce the text exactly. `Int.init(_:)` alone accepts the aliases.
    // Public because the document readers hold the same line.
    public init?(spelling: String) {
        guard case let .int(number) = IntSpelling(spelling) else { return nil }

        self = number
    }
}
