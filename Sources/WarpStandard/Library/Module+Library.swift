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
    // documents of `lib/standard`.
    //
    // Plain Warp modules with no standing of their own: a host that brings a
    // procedure of its own under one of these names links that one instead.
    // What they save is every implementation writing these again, and they are
    // carried in the library rather than read off a disk so that taking this
    // package is the whole of taking the vocabulary.
    //
    // Nothing from outside reaches these documents, so one that will not read
    // is a mistake in `lib/standard`, and the assertion is where it shows. Past it,
    // the bundle stands without its written half.
    static let library: [String: Module] = Library.documents.compactMapValues { text in
        let module = try? Loader().load(TextEncoding().value(from: text), identity: nil)

        assert(module != nil, "a document of lib/standard reads")

        return module
    }

    // A bundle and what `lib/standard` writes for it. A bundle is taken whole, so
    // which of its procedures the host wrote and which the language did is not
    // a thing a host picks apart; it is two modules rather than one because
    // a module is compiled against the modules standing before it, and a
    // declaration the host answers has no body to compile.
    //
    // Merged into one, a bundle would need whatever its written half sends to
    // stand before it, so two bundles whose written halves send to each
    // other's declared halves would have no order. Apart, every half the host
    // answers stands first with nothing to wait for.
    static func bundled(_ bundle: Module, with written: String) -> [Module] {
        guard let document = library[written] else { return [bundle] }

        return [bundle, document]
    }
}
