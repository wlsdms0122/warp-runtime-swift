//
//  Name.swift
//  Warp
//
//  Created by JSilver on 8/21/26.
//

import Foundation

// What being a name costs: one spelling. Unicode writes `é` two ways — one
// scalar, or `e` plus a combining mark — and the two look identical while
// comparing as different bytes. A name is normal form C or it is refused, so a
// declaration and a reference can only meet by being the same bytes.
//
// One predicate rather than one per checker, because the rule is the
// language's and not any checker's own: the encodings hold record keys to it,
// and validation holds every name a program writes as a value to it, and both
// have to mean the same thing by "normal".
public enum Name {
    // MARK: - Property
    // MARK: - Public
    // Compared as bytes on purpose: Swift's `==` compares under canonical
    // equivalence, which would call two spellings equal — the confusion being
    // refused.
    public static func isNormal(_ name: String) -> Bool {
        name.precomposedStringWithCanonicalMapping.utf8.elementsEqual(name.utf8)
    }

    // An identifier as every encoding writes one bare: ASCII on purpose, since
    // "is this a letter" for the rest of Unicode is answered by whatever
    // tables a host language shipped, and a canonical layout cannot depend
    // on whose tables were newer. A name outside this set is quoted where a
    // key stands, and is no type's name. ASCII is its own normal form.
    public static func isIdentifier(_ name: String) -> Bool {
        func word(_ character: Character, first: Bool) -> Bool {
            character.isASCII
                && (character.isLetter || character == "_" || (!first && character.isNumber))
        }

        guard let first = name.first, word(first, first: true) else { return false }

        return name.allSatisfy { character in word(character, first: false) }
    }

    // A declared type's name, and so a record's: identifiers joined by dots.
    // A scalar's word is no name: a bare `true` in front of a record would be
    // read as the record's name, and the value would be gone.
    public static func isTypeName(_ name: String) -> Bool {
        name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { segment in
            isIdentifier(String(segment)) && !["null", "true", "false"].contains(String(segment))
        }
    }

    // MARK: - Private
}
