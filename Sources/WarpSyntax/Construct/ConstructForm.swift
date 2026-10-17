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
public protocol ConstructForm: Sendable, Decodable {
    // The spelling this form proposes. `ConstructRegistry` may register it
    // under another, so a form never learns which key actually reached it. A
    // key is a fact about a notation, and a form is not one.
    static var key: Name { get }

    // Whether this form reads `body` as a key it must have, which a writer
    // asks so that it never drops an empty body a reader demands.
    static var requiresBody: Bool { get }

    // Procedures this form's expression sends, which a link has to declare for the
    // spelling to reach anything. Most forms build the language's own constructs
    // and send nothing, so most leave this empty.
    //
    // These are the procedures the form itself sends; what a notation's
    // spellings spend is the notation's.
    static func vocabulary(with notation: Notation) -> Set<Name>

    // Throws when the form cannot be the statement it was written as.
    func expression(boundTo name: Name?) throws -> Warp.Expression

    // The statement this form is, with the binding it was written under. A
    // form that spends into more than one statement says so here, inside a
    // body of its own, so the names it adds are read nowhere after it.
    func statement(binding: Statement.Binding?) throws -> Statement
}

public extension ConstructForm {
    static var requiresBody: Bool { false }

    static func vocabulary(with notation: Notation) -> Set<Name> { [] }

    func statement(binding: Statement.Binding?) throws -> Statement {
        Statement(binding: binding, expression: try expression(boundTo: binding?.introduced))
    }
}
