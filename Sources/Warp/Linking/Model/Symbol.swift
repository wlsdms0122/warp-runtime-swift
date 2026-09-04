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

    // Which module declared it, by position in the link, so two modules a
    // caller built are still two modules.
    let origin: Int

    let procedure: Procedure

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared.spelling, in: document) }

    // What a sentence calls this declaration when it names one among several.
    // The position is the document's discriminator where it has no identity,
    // and this is the one place that holds both.
    var spelled: String { document.spelled(at: origin) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
