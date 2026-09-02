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

    // A declared type's name, and so a record's: ASCII identifiers joined by
    // dots, which every encoding writes bare. ASCII is its own normal form,
    // so this is the one grammar and the two encodings share it.
    public static func isTypeName(_ name: String) -> Bool {
        !name.isEmpty
            && name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { segment in
                guard let first = segment.first, first.isASCII, first.isLetter || first == "_" else { return false }

                return segment.dropFirst().allSatisfy { character in
                    character.isASCII && (character.isLetter || character.isNumber || character == "_")
                }
            }
    }

    // MARK: - Private
}
