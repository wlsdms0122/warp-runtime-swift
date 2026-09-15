//
//  Identity.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Which document this is, worked out from what it says rather than from what it
// is called.
//
// Nothing a document says about itself can do this job. What a document
// writes is declarations, and two documents may declare spellings under one
// prefix (a program split across files), so nothing written in one tells it
// from the other.
//
// Nor can a file path. A document arrives as bytes, over a wire that carries no
// container and no name for one; a runtime that asked where a document came
// from would be asking a question only some callers can answer.
//
// What is always there is the document itself. So identity is derived from it
// and never declared: nothing writes this down, which is what makes it
// impossible to write down wrongly. Two callers holding the same document work
// out the same answer without having agreed on anything but the language.
//
// Deriving it is `WarpSyntax`'s. The canonical bytes are the one form a
// document already has exactly one of, and reusing them is how a second
// implementation gets this right by getting the wire right. This type is here
// so that a place can carry one without the language learning how bytes are
// written.
public struct Identity: ContentAddress {
    // MARK: - Property
    public let bytes: [UInt8]

    // MARK: - Initializer
    // What makes an identity worth having is that it is derived and never
    // declared. This door cannot say so: what derives one reads a document as
    // bytes, and reading bytes is another package's, so the door it needs is
    // open to every caller.
    //
    // What keeps the rule is that the one place an identity arrives already
    // written down is the reading of an artifact, and that reading is handed
    // the identity the artifact was kept under and refuses any other. A
    // number written in reaches no build.
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    // MARK: - Public
    // MARK: - Private
}
