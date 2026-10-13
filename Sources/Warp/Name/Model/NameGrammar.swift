//
//  NameGrammar.swift
//  Warp
//
//  Created by JSilver on 10/9/26.
//

import Foundation

// Which names may be written where. Each place below holds a name to its own
// grammar:
//
// - a type's name: a type or a contract a module declares. Identifiers
//   joined by dots, a dot being a character of the name.
// - a mention: a type or a contract named in a type, and a struct's name. A
//   type's name, or a name the language declares itself.
// - a contract's mention: the contract a bound, a part joined with `&` or a
//   claim names. A type's name, or the contract the language declares, since
//   a struct the language declares is no contract.
// - a claimed type: the type a claim is about. A mention, or a type the
//   language names a value an instance of.
// - a type parameter's name: the `T` of `some T` and a key of `bounds`. One
//   identifier, since the signature that names it is the only place it means
//   anything.
// - a value's name: a constant, a module variable, a parameter, a statement's
//   name, a loop's round, an attempt's failure and a struct type's field. What
//   a path reads back as one name, since a path is how each one is reached,
//   and there a dot is a step.
// - a contract's procedure's name: the key it is asked under. One identifier,
//   since a call spells it after the contract's name and a dot, and a dot in
//   it would make one spelling two contracts' procedures.
// - a member's name: the key a type is given a procedure under. One
//   identifier, for the same reason after the type's name.
// - a type member's name: the name a contract asks a type under and a type
//   gives one under. One identifier, since `some T.Item` writes it after
//   the type parameter's name and a dot.
//
// No type's name and no type parameter's name is a word the language writes
// itself: the names it gives its own types, the words a type's spelling
// writes in front of a type, and the scalars a value is written as bare.
public enum NameGrammar: Sendable {
    case type
    case mention
    case contractMention
    case claimedType
    case typeParameter
    case value
    case contractProcedure
    case member
    case typeMember

    // MARK: - Property
    static let reserved: Set<Name> = Set(TypeExpression.keywords.keys)
        .union(TypeExpression.nominalTypes.keys)
        .union(Prelude.names)
        .union([
            TypeSpelling.some,
            TypeSpelling.const,
            TypeSpelling.isolated,
            TypeSpelling.inout,
            TypeSpelling.variable
        ])
        .union(Name.scalarKeywords.keys.map(Name.init(normal:)))

    private static let dot = UInt8(ascii: ".")

    private static let pathPunctuation: Set<Character> = [".", "[", "]", "?"]

    // MARK: - Initializer
    // MARK: - Public
    // Whether a name written here is one this grammar takes.
    public func holds(_ name: Name) -> Bool {
        switch self {
        // `Self.Item` is an associated type of `Self`, so no type's name
        // begins there.
        case .type:
            return !NameGrammar.reserved.contains(name) && NameGrammar.joinsIdentifiers(name)
                && !name.spelling.hasPrefix("\(TypeSpelling.selfType.spelling).")

        case .mention:
            return Prelude.names.contains(name) || NameGrammar.type.holds(name)

        case .contractMention:
            return Prelude.contracts[name] != nil || NameGrammar.type.holds(name)

        case .claimedType:
            return TypeExpression.nominalTypes[name] != nil || NameGrammar.mention.holds(name)

        case .typeParameter:
            return !NameGrammar.reserved.contains(name) && name.isIdentifier

        // White space at a name's ends is not part of it where a path is read.
        case .value:
            guard
                let first = name.spelling.unicodeScalars.first,
                let last = name.spelling.unicodeScalars.last
            else {
                return false
            }

            return !name.spelling.contains { character in NameGrammar.pathPunctuation.contains(character) }
                && !Path.whiteSpace.contains(first)
                && !Path.whiteSpace.contains(last)

        case .contractProcedure, .member, .typeMember:
            return name.isIdentifier
        }
    }

    // Whether a name is identifiers joined by dots: a type's name before the
    // words the language writes itself are set aside. A dot is a dot wherever
    // it stands, including where the scalar after it combines with it into
    // one character, so the name is split on its bytes. A dot at either end
    // stands for an empty segment, which is no identifier.
    public static func joinsIdentifiers(_ name: Name) -> Bool {
        name.spelling.utf8
            .split(separator: dot, omittingEmptySubsequences: false)
            .allSatisfy(Name.isIdentifier)
    }

    // Why a name written here is refused: one sentence to a grammar, whoever
    // wrote the name.
    public func refusal(of name: Name) -> String {
        switch self {
        case .type, .mention, .contractMention, .claimedType:
            return "'\(name)' is no name a module gives a type or a contract: such a name is identifiers"
                + " joined by dots, not beginning `Self.`, which writes an associated type of `Self`, and a word the"
                + " language writes itself (`Int`, `some`, `null` and the rest) is the language's"

        case .typeParameter:
            return "'\(name)' is no type parameter's name. A type parameter is named by one identifier,"
                + " and a word the language writes itself (`Int`, `Self`, `some` and the rest) is the language's"

        case .value:
            return "'\(name)' is no name a path reads. A path is written with `.`, `[`, `]` and `?`,"
                + " so a name holding one, or white space at either end, is never the one it reaches"

        case .contractProcedure:
            return "'\(name)' is no name of a contract's procedure. A call writes the contract's name, a dot"
                + " and the procedure's, so the procedure is named by one identifier"

        case .member:
            return "'\(name)' is no member's name. A call writes the type's name, a dot and the member's,"
                + " so a member is named by one identifier"

        case .typeMember:
            return "'\(name)' is no type member's name. A type writes a type parameter's name, a dot and"
                + " the member's, `some T.Item`, so a type member is named by one identifier"
        }
    }

    // MARK: - Private
}
