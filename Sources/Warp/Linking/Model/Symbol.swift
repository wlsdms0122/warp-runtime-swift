//
//  Symbol.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// One declaration, together with where it was declared. The linker needs the
// second half: a name written inside a module means that module's declaration
// first, so resolving a call takes the call's origin and not only its spelling.
struct Symbol: Sendable {
    // MARK: - Property
    // The key this declaration is written under in its module, and the name
    // the module writes. What a reader has to look for in the text is these
    // two: `procedures` holds the declared key and never the module's name.
    let declared: String
    let document: Place.Document

    // Which module declared it, by position in the link. Identity rather than
    // name, so two unnamed modules are still two modules.
    let origin: Int

    let procedure: Procedure

    // What this declaration is called across the whole link. `module.name`
    // where the module has a name, and the bare name where it has none — a
    // module the caller never named has nothing to qualify with, so it declares
    // into the shared space the way a translation unit without a namespace
    // does. Worked out rather than stored, since the two halves are here and a
    // stored copy is a second place the joining could be written differently.
    var qualified: String {
        guard case let .named(module) = document else { return declared }

        return "\(module).\(declared)"
    }

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared, in: document) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
