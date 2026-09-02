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

    // The words the text encoding reads bare as values, and what each one
    // is. A name is never one of them: a bare `true` in front of a record
    // would otherwise be read as the record's name, and the value would be
    // gone.
    public static let scalarWords: [String: Value] = [
        "null": .null,
        "true": .bool(true),
        "false": .bool(false)
    ]

    // A name as a declaration, a notation's prefix and a record's name all
    // spell it: identifiers joined by dots, and not a scalar's word.
    public static func isName(_ name: String) -> Bool {
        scalarWords[name] == nil
            && name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { segment in
                isIdentifier(String(segment))
            }
    }

    // MARK: - Private
}
