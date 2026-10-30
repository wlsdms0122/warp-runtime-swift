//
//  TypeParser.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A type's spelling cut into its syntax: the one reading of the type
// grammar, which the load judges and the text writes as a node. It keeps
// what is written, the order of its parts and a part written twice, and
// refuses only a spelling the grammar gives no structure. White space around
// a part is no part of it.
//
// A type written inside another is one level deeper; a modifier, and the
// parentheses grouping a type, add none. A type nests no
// deeper than a document may, counted on from the containers around its
// string.
struct TypeParser {
    // A spelling's outermost form, and the text of each type it holds, not
    // yet read.
    private indirect enum Form {
        case marked(TypeSyntax.Mark, String)
        case modified([TypeSyntax.Modifier], Form)
        case procedure(String, TypeSyntax.Throwing?, String)
        case optional(String)
        case applied(String, String)
        case holding(TypeSyntax)
    }

    // MARK: - Property
    private static let deeper = "the type nests deeper than a document may, \(Value.nestingBound) levels: the containers"
        + " around its string count, and a type written inside another is one level deeper than it"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // `depth` is how many containers stand around the string the type is
    // written in.
    func parse(_ text: String, at depth: Int = 0) throws -> TypeSyntax {
        try type(text, depth: depth)
    }

    // The contracts an `&` outside every bracket joins, or the one the text
    // is where none does.
    func bound(_ text: String) -> TypeSyntax.Bound {
        TypeSyntax.Bound((joined(text) ?? [Substring(text)]).map(trimmed))
    }

    // A name where it is introduced: the name before the first `:`, and the
    // bound after it where one is written.
    func introduced(_ text: String) -> TypeSyntax.Introduced {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

        return TypeSyntax.Introduced(trimmed(parts[0]), bound: parts.count > 1 ? bound(String(parts[1])) : nil)
    }

    // A name written alone: an associated type of `Self` where its first
    // part is `Self` and a dot follows, and the name otherwise.
    func named(_ text: String) -> TypeSyntax {
        let parts = dotted(Substring(text))

        guard parts.count > 1, parts[0] == TypeSpelling.selfType.spelling else { return .name(text) }

        return .associated(TypeSyntax.Associated(.selfType, members: Array(parts.dropFirst())))
    }

    // What `some` writes in front of a name: an associated type where the
    // name writes a dot and no bound stands beside it, and a type parameter
    // otherwise.
    func some(_ introduced: TypeSyntax.Introduced) -> TypeSyntax {
        let parts = dotted(Substring(introduced.name))

        guard parts.count > 1, introduced.bound == nil else { return .parameter(introduced) }

        return .associated(TypeSyntax.Associated(.parameter(parts[0]), members: Array(parts.dropFirst())))
    }

    // MARK: - Private
    // A level of the walk cuts the spelling's outermost form without reading
    // what it holds, in a function of its own, and then reads each part it
    // holds: the cut holds every check, so a level of the recursion holds
    // little more than the dispatch.
    private func type(_ written: String, depth: Int) throws -> TypeSyntax {
        guard depth <= Value.nestingBound else {
            throw TypeSyntaxError(Self.deeper)
        }

        return try read(try cut(written), depth: depth)
    }

    private func read(_ form: Form, depth: Int) throws -> TypeSyntax {
        switch form {
        case let .marked(mark, inner):
            return .marked(mark, try type(inner, depth: depth + 1))

        case let .modified(modifiers, inner):
            return .modified(modifiers, try read(inner, depth: depth))

        case let .procedure(inside, throwing, returns):
            return try procedure(inside, throwing, returns, depth: depth)

        case let .optional(inner):
            return .optional(try type(inner, depth: depth + 1))

        case let .applied(head, inner):
            return .applied(head, try types(inner, depth: depth))

        case let .holding(syntax):
            return syntax
        }
    }

    private func procedure(
        _ inside: String,
        _ throwing: TypeSyntax.Throwing?,
        _ returns: String,
        depth: Int
    ) throws -> TypeSyntax {
        .procedure(
            inside.isEmpty ? [] : try types(inside, depth: depth),
            throwing: throwing,
            returns: try type(returns, depth: depth + 1)
        )
    }

    // The types a list holds, split at each comma standing outside every
    // inner bracket and parenthesis, a level deeper than what holds them.
    private func types(_ inner: String, depth: Int) throws -> [TypeSyntax] {
        var types: [TypeSyntax] = []

        for part in split(inner, at: ",") {
            types.append(try type(String(part), depth: depth + 1))
        }

        return types
    }

    // The outermost form a spelling writes. `inout` and `var` stand in front
    // of the whole type, a trailing `?` included, and so do modifiers; what
    // follows `->` is a procedure's return type to the end of the spelling, so
    // the arrow is cut before a trailing `?`.
    private func cut(_ written: String) throws -> Form {
        let text = try ungrouped(written)

        if let mark = TypeSyntax.Mark.allCases.first(where: { mark in text.hasPrefix("\(mark.word) ") }) {
            return .marked(mark, String(text.dropFirst(mark.word.spelling.count + 1)))
        }

        if let modified = try modified(text) {
            return modified
        }

        if let arrow = arrow(in: text) {
            let (inside, throwing) = try signature(text[..<arrow])

            return .procedure(inside, throwing, String(text[text.index(arrow, offsetBy: 2)...]))
        }

        if text.hasSuffix("?") {
            return .optional(trimmed(text.dropLast()))
        }

        if let unapplied = try unapplied(text) {
            return .holding(unapplied)
        }

        return try applied(text)
    }

    // The text without the white space around it, and without parentheses
    // around the whole of it, which group the type they hold. Which types a
    // group is the one spelling of is the write-back's to judge, as it is
    // for every other part of a type.
    private func ungrouped(_ written: String) throws -> String {
        let outer = trimmed(written)
        let text = parenthesized(outer).map(trimmed) ?? outer

        guard !text.isEmpty else {
            throw TypeSyntaxError("a type name must not be empty")
        }

        return text
    }

    // The modifiers in front of a type, in the order written, and the form
    // after them, which they add no level to.
    private func modified(_ text: String) throws -> Form? {
        var rest = Substring(text)
        var modifiers: [TypeSyntax.Modifier] = []

        while let modifier = TypeSyntax.Modifier.allCases.first(where: { modifier in rest.hasPrefix("\(modifier.word) ") }) {
            modifiers.append(modifier)
            rest = rest.dropFirst(modifier.word.spelling.count + 1)
        }

        guard !modifiers.isEmpty else { return nil }

        return .modified(modifiers, try cut(String(rest)))
    }

    // What stands before a procedure type's `->`: its parameters in
    // parentheses, and then what it may fail with.
    private func signature(_ written: Substring) throws -> (inside: String, throwing: TypeSyntax.Throwing?) {
        let head = trimmed(written)

        guard head.hasPrefix("("), let close = closing(head) else {
            throw TypeSyntaxError(
                "writes '\(head)' before `->`, and a procedure type writes its parameters in parentheses there:"
                    + " `(Int) -> Bool`"
            )
        }

        return (trimmed(head[head.index(after: head.startIndex) ..< close]), try throwing(head[head.index(after: close)...]))
    }

    // What stands between a procedure type's parameters and `->`: nothing,
    // `throws` alone, or `throws` and the names it lists in parentheses.
    private func throwing(_ written: Substring) throws -> TypeSyntax.Throwing? {
        let text = trimmed(written)

        guard !text.isEmpty else { return nil }

        guard text.hasPrefix(TypeSpelling.throws.spelling) else {
            throw TypeSyntaxError(
                "writes '\(text)' between a procedure type's parameters and `->`, where `throws` stands, alone"
                    + " or with what it may fail with: `(Int) throws(aborted) -> Bool`"
            )
        }

        let rest = text.dropFirst(TypeSpelling.throws.spelling.count)
        let listed = trimmed(rest)

        guard !listed.isEmpty else { return .anything }

        guard let names = parenthesized(listed).map(trimmed) else {
            throw TypeSyntaxError("writes `throws\(rest)`, and what a procedure may fail with is listed in parentheses")
        }

        let failures = names.isEmpty ? [] : split(names, at: ",").map(trimmed)

        if failures.contains(where: \.isEmpty) {
            throw TypeSyntaxError("writes `throws(\(names))`, which leaves a place in the list empty")
        }

        return .these(failures)
    }

    // A type holding no other: what `some` writes, or names an `&` joins.
    // Nil where the text is a name, applied to types or not. A parenthesis
    // that opens it opens nothing a type is.
    private func unapplied(_ text: String) throws -> TypeSyntax? {
        if text.hasPrefix("(") {
            throw TypeSyntaxError(
                "type '\(text)' opens a parenthesis, and parentheses hold a procedure type's parameters before"
                    + " `->` and its return type, `(Int) -> Bool`, or group a type, `((Int) -> Int)?`"
            )
        }

        if text == TypeSpelling.some.spelling || text.hasPrefix("\(TypeSpelling.some) ") {
            return some(introduced(String(text.dropFirst(TypeSpelling.some.spelling.count))))
        }

        if let joined = joined(text) {
            return .composition(TypeSyntax.Bound(joined.map(trimmed)))
        }

        return nil
    }

    // A name, or a name and the text its brackets hold.
    private func applied(_ text: String) throws -> Form {
        guard let open = text.firstIndex(of: "<") else {
            guard !text.contains(">") else {
                throw TypeSyntaxError("type '\(text)' closes an argument it never opened")
            }

            return .holding(named(text))
        }

        guard text.hasSuffix(">") else {
            throw TypeSyntaxError("type '\(text)' opens an argument it never closes")
        }

        return .applied(trimmed(text[..<open]), String(text[text.index(after: open) ..< text.index(before: text.endIndex)]))
    }

    // The text cut at every dot, each part as written.
    private func dotted(_ text: Substring) -> [String] {
        text.split(separator: ".", omittingEmptySubsequences: false).map(trimmed)
    }

    private func trimmed(_ text: some StringProtocol) -> String {
        text.trimmingCharacters(in: Path.whiteSpace)
    }

    // The parts an `&` standing outside every bracket joins, or nothing
    // where none does.
    private func joined(_ text: String) -> [Substring]? {
        let parts = split(text, at: "&")

        return parts.count > 1 ? parts : nil
    }

    // The first `->` standing outside every bracket and parenthesis, which
    // ends a procedure type's parameters.
    private func arrow(in text: String) -> String.Index? {
        outside(text).first { index in
            text[index...].hasPrefix("->")
        }
    }

    // What stands between a parenthesis opening the text and the one closing
    // it, where the one closing it is the text's last.
    private func parenthesized(_ text: String) -> String? {
        guard text.hasPrefix("("), let close = closing(text), text.index(after: close) == text.endIndex else {
            return nil
        }

        return String(text[text.index(after: text.startIndex) ..< close])
    }

    // The parenthesis closing the one the text opens with.
    private func closing(_ text: String) -> String.Index? {
        var depth = 0

        for (index, character) in zip(text.indices, text) {
            switch character {
            case "(":
                depth += 1

            case ")":
                depth -= 1

                if depth == 0 {
                    return index
                }

            default:
                break
            }
        }

        return nil
    }

    // The text split at each `separator` standing outside every bracket and
    // parenthesis.
    private func split(_ text: String, at separator: Character) -> [Substring] {
        var parts: [Substring] = []
        var start = text.startIndex

        for index in outside(text) where text[index] == separator {
            parts.append(text[start ..< index])
            start = text.index(after: index)
        }

        return parts + [text[start...]]
    }

    // Where the text stands outside every bracket and parenthesis. The `>` of
    // an arrow closes nothing.
    private func outside(_ text: String) -> [String.Index] {
        var depth = 0
        var found: [String.Index] = []
        var previous: Character?

        for (index, character) in zip(text.indices, text) {
            switch character {
            case "<", "(":
                depth += 1

            case ">" where previous != "-", ")":
                depth -= 1

            default:
                if depth == 0 { found.append(index) }
            }

            previous = character
        }

        return found
    }
}
