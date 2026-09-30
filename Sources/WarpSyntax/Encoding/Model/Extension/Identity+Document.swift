//
//  Identity+Document.swift
//  WarpSyntax
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Warp

// Working out which document a document is.
//
// Here and not beside the language, because the answer is about bytes: a
// document has exactly one canonical binary writing, and that is already what
// this target is for. Deriving the identity from it means a second
// implementation gets identity right by getting the wire right. There is no
// second ordering rule to agree on, no second place to sort keys, nothing to
// implement twice and disagree about once.
//
// What it is a function of is the *document*, and not of how the document was
// written down. Text in and bytes in answer alike, because both are read into
// the same tree before anything is hashed, so a program does not change
// identity by changing notation, encoding, or the spellings its author reached
// for. What it is not a function of is anything outside the document: no path
// and no name.
//
// It is a function of everything *inside* it, down to the order of an array,
// which is more than the language calls a difference. Two documents listing the
// same imports in two orders are one program and two documents to this, because
// what is being told apart is which text a refusal came out of, and a text that
// was rewritten is not the text somebody is holding.
//
// Two sides that want to agree therefore have to hash the same document, which
// is the whole of the contract. A front end hashes the document it produced; a
// runtime hashes the document it received; if what was received is what was
// produced, the answers meet. A document rewritten on the way (even into
// something the language would call the same program) is a different document
// to this, and the failure is a refusal nobody can place rather than a refusal
// placed wrongly.
public extension Identity {
    // Nothing is stored and nothing is claimed. This is worked out from the
    // document every time it is wanted, which is what makes it impossible for
    // anybody to record it wrongly.
    static func of(_ document: Value) throws -> Identity {
        Identity(SHA256().digest(of: try BinaryEncoding().data(from: document)))
    }
}
