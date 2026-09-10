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
    // A word a host brought, beside what it declares about itself. Read once
    // when the supply is built: a link asks the same questions of the same
    // words every time it joins them up.
    struct Brought: Sendable {
        let word: Native

        // What the module bringing it declared it takes and answers. A row
        // stands on the declaration it was compiled against, so this is what
        // says the two are one word.
        let signature: Signature
        let sending: [Name]

    }

    // MARK: - Property
    // A caller bringing no native code at all. What a document left to its
    // host is then refused wherever it stands.
    public static let none = Supplying()

    private let words: [Name: Brought]

    // MARK: - Initializer
    private init() {
        self.words = [:]
    }

    // A spelling two of them bring is refused here, for the reason a link
    // refuses a name two documents declare: a table with two answers for one
    // name has no answer, and which of the two a run would get is the order
    // the caller happened to write.
    public init(_ modules: [Module]) throws {
        var words: [Name: Brought] = [:]

        for module in modules {
            for (name, procedure) in module.procedures {
                guard let word = procedure.implementation.native else { continue }

                guard !words.keys.contains(name) else {
                    throw LinkError(
                        "'\(name)' is brought by two of the modules handed over."
                            + " Two words under one spelling have no way to be told apart",
                        at: .procedure(name.spelling, in: .of(module))
                    )
                }

                words[name] = Brought(
                    word: word,
                    signature: procedure.signature,
                    sending: word.sending
                )
            }
        }

        self.words = words
    }

    // MARK: - Public
    // The code brought under that spelling, or nil where the host brought
    // none. What a row does about that is the row's: it is the one holding
    // what its document was compiled against.
    subscript(_ name: Name) -> Brought? {
        words[name]
    }

    // MARK: - Private
}
