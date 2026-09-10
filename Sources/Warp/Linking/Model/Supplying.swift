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
struct Supplying: Sendable {
    // MARK: - Property
    private let words: [Name: Linked.Implementation]

    // MARK: - Initializer
    init(_ modules: [Module]) {
        var words: [Name: Linked.Implementation] = [:]

        for module in modules {
            for (name, procedure) in module.procedures {
                switch procedure.implementation {
                case .body:
                    continue

                case let .query(query):
                    words[name] = .query(query)

                case let .effect(effect):
                    words[name] = .effect(effect)
                }
            }
        }

        self.words = words
    }

    // MARK: - Public
    // The code declared under that spelling. A link handed none has nothing to
    // run for that row, so it is refused here rather than where the call is
    // made: what a caller brings is a statement about the whole run.
    func word(_ name: Name, in document: Place.Document) throws -> Linked.Implementation {
        guard let word = words[name] else {
            throw LinkError(
                "'\(name)' is implemented in native code and this link was handed none."
                    + " What a caller brings is declared where the run is assembled",
                at: .procedure(name.spelling, in: document)
            )
        }

        return word
    }

    // MARK: - Private
}
