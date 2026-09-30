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
        try! Loader().load(try! TextEncoding().value(from: text), identity: nil)
    }

    // A bundle and what `lib/std` writes for it. A bundle is taken whole, so
    // which of its procedures the host wrote and which the language did is not
    // a thing a caller picks apart; it is two modules rather than one because
    // a module is compiled against the modules standing before it, and a
    // declaration the host answers has no body to compile.
    //
    // Merged into one, a bundle would need whatever its written half sends to,
    // and the bundles it declares for stand above it: `std.logic` walks, so it
    // sends `std.collection.count`, and a collection procedure comparing two
    // elements sends `std.logic.equal`. Apart, `equal` stands first with
    // nothing to wait for and the ring never forms.
    static func bundled(_ bundle: Module, with written: String) -> [Module] {
        guard let document = library[written] else { return [bundle] }

        return [bundle, document]
    }
}
