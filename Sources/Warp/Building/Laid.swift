//
//  Laid.swift
//  Warp
//
//  Created by JSilver on 9/11/26.
//

import Foundation

// Documents already compiled, with the rows they stand as made once.
//
// What a document is compiled against is other documents, and turning those
// into rows is work: each declaration's signature lowered into slots, and each
// native joined to the code the host brought under its spelling. A caller
// compiling one document after another against the same documents would pay
// for that once a document. This is where it is paid once.
//
// The rows a document takes are the rows after the ones already laid, and both
// shape spaces number by the order their documents stand, so a document laid
// down later takes numbers past these and moves none of them. That is what
// lets rows made here stand in a compile that puts more documents beside them.
public struct Laid: Sendable {
    // MARK: - Property
    let compiled: [Compiled]

    // Each document's rows: its declarations in the order their rows stand,
    // then the closures its bodies lifted.
    let rows: [[Linked]]

    // What the build read off a body whose declaration wrote no `returns`, as
    // the rows above read it.
    let answers: [Name: Shape]

    // The link these rows are numbered against. A compile against them
    // numbers the documents it lays beside them into the same one.
    let linkage: Linkage

    // The code the natives among them were joined to, kept so a compile
    // against them joins the documents it lays to the same words.
    let supplied: Supplying

    // Nothing laid down, for a build that was handed no documents to compile
    // against.
    static let none = Laid(compiled: [], rows: [], answers: [:], linkage: Linkage(), supplied: .none)
}
