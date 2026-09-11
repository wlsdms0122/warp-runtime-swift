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

    // Where this declaration's rows stand in the link, written when the link
    // lays them. Until then it is where the module sits in the list this was
    // read out of, which is what groups these back by module.
    let origin: Int

    // Where the caller put that module in the list it handed over. What a
    // sentence names, since a caller reading a refusal counts its own list
    // rather than the order the link worked out.
    let handed: Int

    let procedure: Procedure

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared.spelling, in: document) }

    // What a sentence calls this declaration when it names one among several.
    // The position is the document's discriminator where it has no identity,
    // and this is the one place that holds both.
    var spelled: String { document.spelled(at: handed) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
