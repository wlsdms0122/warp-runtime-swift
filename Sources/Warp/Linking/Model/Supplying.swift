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
    private let words: [Name: Native]

    // MARK: - Initializer
    init(_ modules: [Module]) {
        var words: [Name: Native] = [:]

        for module in modules {
            for (name, procedure) in module.procedures {
                words[name] = procedure.implementation.native
            }
        }

        self.words = words
    }

    // MARK: - Public
    // The code standing behind a row its document left to native code, held
    // to what that document was compiled against.
    //
    // A link handed no code for the row has nothing to run, so it is refused
    // here rather than where the call is made: what a caller brings is a
    // statement about the whole run.
    //
    // A word declares its own purity, isolation and failing, and the row
    // carries what the word a compile was handed declared. A host bringing a
    // word that says something else brings a row judged against claims
    // nothing in this link makes.
    func word(behind judged: Judged, in document: Place.Document) throws -> Linked.Implementation {
        guard let word = words[judged.label] else {
            throw LinkError(
                "'\(judged.label)' is implemented in native code and this link was handed none."
                    + " What a caller brings is declared where the run is assembled",
                at: .procedure(judged.label.spelling, in: document)
            )
        }

        guard
            judged.purity == word.purity,
            judged.isolation == word.isolation,
            judged.failing == word.failing
        else {
            let differing = [
                judged.purity == word.purity ? nil : "purity",
                judged.isolation == word.isolation ? nil : "isolation",
                judged.failing == word.failing ? nil : "failing"
            ].compactMap { axis in axis }

            throw LinkError(
                "'\(judged.label)' stands on what the word a compile was handed said"
                    + " about its \(differing.joined(separator: ", ")), and the word"
                    + " brought under that spelling says otherwise",
                at: .procedure(judged.label.spelling, in: document)
            )
        }

        switch word {
        case let .query(query):
            return .query(query)

        case let .effect(effect):
            return .effect(effect)
        }
    }

    // MARK: - Private
}
