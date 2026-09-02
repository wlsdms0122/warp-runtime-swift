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
    // The key this declaration is written under in its module, and the name
    // the module writes. What a reader has to look for in the text is these
    // two: `procedures` holds the declared key and never the module's name.
    let declared: String

    // Which document this was written in, and what the module it was written in
    // calls itself. Two documents may declare into one namespace, so the name
    // qualifies and the document identifies, and neither stands in for the
    // other — they travel together because both are the same module's answer.
    let document: Place.Document

    // Which module declared it, by position in the link. Identity rather than
    // name, so two unnamed modules are still two modules.
    let origin: Int

    let procedure: Procedure

    // What this declaration is called across the whole link. `module.namespace`
    // where the module has a name, and the bare name where it has none — a
    // module the caller never named has nothing to qualify with, so it declares
    // into the shared space the way a translation unit without a namespace
    // does. Worked out rather than stored, since the two halves are here and a
    // stored copy is a second place the joining could be written differently.
    var qualified: String {
        guard let namespace = document.namespace else { return declared }

        return "\(namespace).\(declared)"
    }

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared, in: document) }

    // What a sentence calls this declaration when it names one among several.
    // The position is the document's discriminator where it has no identity,
    // and this is the one place that holds both.
    var spelled: String { document.spelled(at: origin) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
