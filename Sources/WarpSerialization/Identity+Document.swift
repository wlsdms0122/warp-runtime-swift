//
//  Identity+Document.swift
//  WarpSerialization
//
//  Created by JSilver
//

import Foundation
import Warp

// Working out which document a document is.
//
// Here and not beside the language, because the answer is about bytes: a
// document has exactly one canonical binary writing, and that is already what
// this target is for. Deriving the identity from it means a second
// implementation gets identity right by getting the wire right — there is no
// second ordering rule to agree on, no second place to sort keys, nothing to
// implement twice and disagree about once.
//
// It is the *canonical binary* writing and not the bytes that happened to
// arrive. A document written as text and the same document written as bytes are
// one document, so they answer with one identity; and a document written by a
// caller that never sent it anywhere has one too.
public extension Identity {
    // Nothing is stored and nothing is claimed — this is worked out from the
    // document every time it is wanted, which is what makes it impossible for
    // anybody to record it wrongly.
    static func of(_ document: Value) throws -> Identity {
        Identity(SHA256.digest(of: try BinaryEncoding.data(from: document)))
    }
}
