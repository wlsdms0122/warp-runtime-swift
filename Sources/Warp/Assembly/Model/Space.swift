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
}
