//
//  Body+Literal.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// Writing a body in Swift, statement by statement.
extension Body: ExpressibleByArrayLiteral {
    public init(arrayLiteral statements: Statement...) {
        self.init(statements)
    }
}
