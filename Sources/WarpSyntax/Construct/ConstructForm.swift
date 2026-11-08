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
// one surface that says which key builds which. The name a statement
// introduces is the statement's, so a form spells its expression alone.
protocol ConstructForm: Sendable, Decodable {
    // The key a statement's `value` writes this construct under.
    static var key: Name { get }

    var expression: Warp.Expression { get }
}
