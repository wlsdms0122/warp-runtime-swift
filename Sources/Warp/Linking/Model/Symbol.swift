//
//  Symbol.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// One declaration, together with where it was declared. The second half says
// which document a refusal points at, and which module's constants a body
// reads beside its parameters.
struct Symbol: Sendable {
    // MARK: - Property
    // The key this declaration is written under in its module, which is the
    // whole of its name.
    let declared: Name

    // Which document this was written in.
    let document: Place.Document

    // Which module declared it, by where its rows stand in the link. Rows are
    // laid in the order each document's needs stand before it, which is not
    // the order the caller handed them over in.
    let origin: Int

    // Where the caller put that module. What a sentence names, since a caller
    // reading a refusal counts the list it handed over rather than the order
    // the link worked out.
    let position: Int

    let procedure: Procedure

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared.spelling, in: document) }

    // What a sentence calls this declaration when it names one among several.
    // The position is the document's discriminator where it has no identity,
    // and this is the one place that holds both.
    var spelled: String { document.spelled(at: position) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
