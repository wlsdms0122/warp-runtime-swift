//
//  Space.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The two name spaces a declaration can take a name in. A link refuses one
// name standing for a shape and a membership at once, and says nothing about a
// word spelled like a type, so a catalogue keeps a table for each.
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

    // What the document declares in this space. Which declarations those are
    // is the document's own answer; this picks which of its two to ask.
    func declarations(of draft: Draft, in document: Place.Document) -> [(name: Name, place: Place)] {
        switch self {
        case .word: draft.words(in: document)
        case .shape: draft.shapes(in: document)
        }
    }
}
