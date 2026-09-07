//
//  Space.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The two name spaces a declaration can take a name in, and what a document
// declares in each. A link refuses one name standing for a shape and a
// membership at once, and says nothing about a word spelled like a type, so a
// catalogue keeps a table for each and this is what fills it.
enum Space {
    case word
    case shape

    // MARK: - Internal
    var spelled: String {
        switch self {
        case .word: "word"
        case .shape: "shape"
        }
    }

    // What the document declares in this space, each under the place it was
    // written at.
    func declarations(of draft: Draft, in document: Place.Document) -> [(name: Name, place: Place)] {
        switch self {
        case .word:
            draft.procedures.keys.map { name in
                (name, .procedure(name.spelling, in: document))
            }
                + draft.contractWords.map { name in
                    (name, .contract(name.spelling, in: document))
                }

        case .shape:
            draft.types.keys.map { name in
                (name, .type(name.spelling, in: document))
            }
                + draft.constraints.keys.map { name in
                    (name, .constraint(name.spelling, in: document))
                }
                + draft.contracts.keys.map { name in
                    (name, .contract(name.spelling, in: document))
                }
        }
    }
}
