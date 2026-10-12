//
//  Name+Literal.swift
//  Warp
//
//  Created by JSilver on 9/30/26.
//

import Foundation

// A name written in Swift. The spelling is source an author typed, so a
// spelling that is not a name is a mistake being made where it can be read, and
// there is nothing to answer with. The same reaction a duplicate key in a value
// literal gets. A spelling that arrived from anywhere else goes through the
// throwing initializer.
extension Name: ExpressibleByStringLiteral {
    public init(stringLiteral spelling: String) {
        do {
            try self.init(spelling)
        } catch {
            preconditionFailure("'\(spelling)' cannot be a name: \(error)")
        }
    }
}
