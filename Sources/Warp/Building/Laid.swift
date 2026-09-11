//
//  Laid.swift
//  Warp
//
//  Created by JSilver on 9/11/26.
//

import Foundation

// Documents already compiled, laid down as a compile against them carries
// them.
//
// What a document is compiled against is other documents, and turning those
// into what a compile reads is work: each declaration's signature lowered into
// slots, each native joined to the code the host brought under its spelling,
// and every number their bodies carry answered with the row it reaches. A
// caller compiling one document after another against the same documents would
// pay for that once a document. This is where it is paid once.
//
// The rows a document takes are the rows after the ones already laid, and both
// shape spaces number by the order their documents stand, so a document laid
// down later takes numbers past these and moves none of them. That is what
// lets what is laid here stand in a compile that puts more documents beside it.
//
// The natives among them are joined to the host's words here, since making a
// row is what joining is. The documents laid beside them later are joined at
// the link, which is where a build states every word its run may call.
public struct Laid: Sendable {
    // MARK: - Property
    public let compiled: [Compiled]

    // The documents laid down: their rows, what each proved about its own
    // bodies, and where every number those bodies carry stands.
    let compiling: Compiling

    // The link these rows are numbered against. A compile against them
    // numbers the documents it lays beside them into the same one.
    let linkage: Linkage

    // Nothing laid down, for a build that was handed no documents to compile
    // against.
    static let none = Laid(
        compiled: [],
        compiling: Compiling(types: .empty, contractWords: [:], answering: [], naming: []),
        linkage: Linkage()
    )
}
