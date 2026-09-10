//
//  Supplying.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// The native code a host brings to a link, by the spelling each word was
// declared under.
//
// A compiled document names the words it left to native code and carries none
// of it. What runs is a Swift value the host built, and a document has no way
// to say what that value is, so the code arrives beside the artifacts and a
// link joins the two by name.
//
// Held by the caller rather than read out of the modules at every call. The
// words a host brings are the same words every run, and joining them up is
// what a link would otherwise pay for again each time.
public struct Supplying: Sendable {
    // MARK: - Property
    private let words: [Name: Native]

    // MARK: - Initializer
    public init(_ modules: [Module]) {
        var words: [Name: Native] = [:]

        for module in modules {
            for (name, procedure) in module.procedures {
                guard let word = procedure.implementation.native else { continue }

                words[name] = word
            }
        }

        self.words = words
    }

    // MARK: - Public
    // The code brought under that spelling, or nil where the host brought
    // none. What a row does about that is the row's: it is the one holding
    // what its document was compiled against.
    subscript(_ name: Name) -> Native? {
        words[name]
    }

    // MARK: - Private
}
