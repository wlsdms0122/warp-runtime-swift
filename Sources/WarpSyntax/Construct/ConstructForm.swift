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

    // Whether this form reads `body` as a key it must have. A writer asks the
    // form rather than keeping its own list of which forms do: the two sides
    // are a file apart, and a writer that drops an empty body a reader demands
    // writes documents that cannot be read back, which is a failure at the far
    // end of a wire, where nobody can see what wrote it.
    static var requiresBody: Bool { get }

    // Procedures this form's expression sends, which a link has to declare for the
    // spelling to reach anything. Most forms build the language's own constructs
    // and send nothing, so most leave this empty.
    //
    // These are the form's own. A procedure it decided to send. What a
    // notation's spellings spend is the notation's.
    static func vocabulary(with notation: Notation) -> Set<Name>

    // Throws when the form cannot be the statement it was written as.
    func expression(boundTo name: Name?) throws -> Warp.Expression
}

public extension ConstructForm {
    static var requiresBody: Bool { false }

    static func vocabulary(with notation: Notation) -> Set<Name> { [] }
}
