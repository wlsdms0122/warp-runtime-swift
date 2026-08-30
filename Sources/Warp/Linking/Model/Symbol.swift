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
    // What this declaration is called across the whole link. `module.name` where
    // the module has a name, and the bare name where it has none — a module the
    // caller never named has nothing to qualify with, so it declares into the
    // shared space the way a translation unit without a namespace does.
    let qualified: String

    // The key this declaration is written under in its module. Kept beside the
    // qualified name because the two answer different questions: what a link
    // calls a declaration is the link's fact, and what a reader has to look for
    // in the text is this — `procedures` holds the declared key and never the
    // module's name, so a place spelled with the qualified one leads nowhere.
    let declared: String

    // The name the declaring module writes, which is the document a place made
    // from `declared` is an address in. Nil where the module wrote none.
    let document: String?

    // Which module declared it, by position in the link. Identity rather than
    // name, so two unnamed modules are still two modules.
    let origin: Int

    let procedure: Procedure

    // Where this declaration's words are, in the document that wrote it.
    var place: Place { .procedure(declared, in: document) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
