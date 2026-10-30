//
//  ConstructForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// How a document spells a construct. A keyword and an expression meet here and
// nowhere else. The language's own constructs have no names, and this is the
// one surface that says which key builds which.
//
// A form is asked for its expression with the name the statement it stands in
// introduces, for a form that binds that name inside what it spells. A `set`
// introduces none.
protocol ConstructForm: Sendable, Decodable {
    // The key a statement's `value` writes this construct under.
    static var key: Name { get }

    // Throws when the form cannot be the statement it was written as.
    func expression(boundTo name: Name?) throws -> Warp.Expression
}
