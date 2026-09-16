//
//  Module+Library.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp
import WarpSyntax

extension Module {
    // The vocabulary written in Warp rather than in Swift, read from the
    // documents of `lib/std`.
    //
    // Plain Warp modules with no standing of their own: a caller that brings a
    // procedure of its own under one of these names links that one instead.
    // What they save is every implementation writing these again, and they are
    // carried in the library rather than read off a disk so that taking this
    // package is the whole of taking the vocabulary.
    //
    // The force is the same one the bundles written in Swift take: there is no
    // caller to hand a refusal to, and a document shipped with the language
    // that will not read is a bug in the language.
    static let library: [String: Module] = Library.documents.mapValues { text in
        try! Loader().load(try! TextEncoding.value(from: text), identity: nil)
    }

    // A bundle and what `lib/std` writes for it, as one module. A bundle is
    // taken whole, so which of its procedures the host wrote and which the
    // language did is not a thing a caller picks apart.
    static func bundled(_ bundle: Module, with written: String) -> Module {
        guard let document = library[written] else { return bundle }

        let procedures = bundle.procedures.merging(document.procedures) { _, new in new }

        return try! Module(
            description: bundle.description,
            // What the pair reaches outside itself. A name one of them declared
            // is no longer sent anywhere but inside.
            imports: bundle.imports.union(document.imports).subtracting(procedures.keys),
            types: bundle.types.merging(document.types) { first, _ in first },
            constraints: bundle.constraints.merging(document.constraints) { first, _ in first },
            procedures: procedures
        )
    }
}
