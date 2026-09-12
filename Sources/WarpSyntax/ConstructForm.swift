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
// one surface that says which procedure builds which.
//
// A form is asked for its expression with the name it is being bound under,
// because two constructs need a name to exist inside their body and this
// notation supplies the statement's own id for it: `loop` binds round state,
// `attempt` binds the failure. In the IR those names are written down; here
// they are inherited from the envelope, which is why the reader hands one
// over.
public protocol ConstructForm: Sendable, Decodable {
    // The spelling this form proposes. `ConstructRegistry` may register it
    // under another, so a form never learns which key actually reached it. A
    // procedure is a fact about a notation, and a form is not one.
    static var key: Name { get }

    // Whether this form opens a condition slot. Answering yes is how a form owns
    // the procedures its notation spends there, without knowing any of them.
    //
    // It is a fact about the form rather than a sum the form computes. A form
    // that had to fetch what its slot spends is a form that can fetch nothing
    // and be believed, and the under-declared debt surfaces as a link failure
    // far from here. A form says which slots it opens; the registry adds up what
    // those slots spend.
    static var readsCondition: Bool { get }

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
    // These are the form's own. A procedure it decided to send. What its slots spend
    // is not here; it is above.
    static func vocabulary(with notation: Notation) -> Set<Name>

    // Throws when the form cannot be the statement it was written as. The one
    // case today being a form that binds through the statement's name, handed
    // no name to bind through.
    func expression(boundTo id: String?) throws -> Expression
}

public extension ConstructForm {
    static var readsCondition: Bool { false }

    static var requiresBody: Bool { false }

    static func vocabulary(with notation: Notation) -> Set<Name> { [] }

    // The name a binding construct binds through. It is the statement's own,
    // which is why these constructs cannot be written nameless: with no name,
    // what the body binds would have to be invented, and an invented name is a
    // real name somewhere. It refuses without an address: a form lowering what
    // it read is past the decoder that knew where the reading was, and the
    // statement this belongs to is what the reader that asked for the lowering
    // is holding. So the sentence is said here and where it happened is said
    // there.
    func named(_ id: String?, in construct: String, binding: String) throws -> Name {
        guard let id else {
            throw ReadingError(
                "a \(construct) binds its \(binding) under the"
                    + " statement's name, so it cannot be written nameless"
            )
        }

        return try Name.read(id, at: [])
    }
}
