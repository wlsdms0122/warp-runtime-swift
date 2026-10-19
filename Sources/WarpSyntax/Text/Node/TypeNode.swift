//
//  TypeNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A type as a node, and the text a tree holds for it: the type grammar's
// spelling, its parts in the order the node writes them. One type, one node:
// a node whose text another node also writes is refused, so a text read back
// is the node it was written as.
//
//   Int  App.Point  Self.Item          a name, as itself
//   (array T)                          Array<T>
//   (dictionary K V)                   Dictionary<K, V>
//   (named App.Box Int)                App.Box<Int>
//   (nullable T)                       T?, (T)? where T is a procedure node
//   (composition A B)                  A & B
//   (some T)  (some T A B)             some T, some T: A & B
//   (inout T)  (var T)                 inout T, var T
//   (procedure (const) (isolated) (parameters A) (failing x) (returns R))
//                                      const isolated (A) throws(x) -> R
//   (procedure (const))                const Procedure
struct TypeNode {
    // MARK: - Property
    // What a name in a type may not hold, since the spelling is cut at it.
    static let cut = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "<>(),:&?"))

    // MARK: - Initializer
    // MARK: - Public
    // The text a node writes, where the node is the one that text reads as.
    func text(of datum: Datum) throws -> String {
        let text = try spelled(datum, depth: 1)

        guard (try? DatumWriter().line(of: parsed(Substring(text), depth: 1))) == (try? DatumWriter().line(of: datum)) else {
            throw Unplaced("'\(text)' is written as another node, and is one type", at: datum.offset)
        }

        return text
    }

    // The node a tree's text is, where a node writes that text back.
    func datum(of text: String) throws -> Datum {
        let datum = parsed(Substring(text), depth: 1)
        let written: String

        do {
            written = try spelled(datum, depth: 1)
        } catch let refusal as Unplaced {
            throw EncodingRefused("the type is written '\(text)', which no node writes: \(refusal.said)")
        }

        guard written == text else {
            throw EncodingRefused("the type is written '\(text)', which no node writes. The nearest writes '\(written)'")
        }

        return datum
    }

    // MARK: - Private
    // A dispatcher and a function a word, so a recursion through a type
    // spends one word's frame a level. A type's nodes nest no deeper than a
    // tree may.
    private func spelled(_ datum: Datum, depth: Int) throws -> String {
        guard depth <= Value.nestingBound else {
            throw Unplaced("the type nests deeper than a document may", at: datum.offset)
        }

        guard case .list = datum.form else { return try name(datum) }

        let node = try Node(datum)

        switch node.word {
        case "array": return try array(node, depth: depth)
        case "dictionary": return try dictionary(node, depth: depth)
        case "named": return try named(node, depth: depth)
        case "nullable": return try nullable(node, depth: depth)
        case "composition": return try composition(node)
        case "some": return try some(node)
        case "inout": return "\(TypeSpelling.inout) \(try spelled(node.one(), depth: depth + 1))"
        case "var": return "\(TypeSpelling.variable) \(try spelled(node.one(), depth: depth + 1))"
        case "procedure": return try procedure(node, depth: depth)
        default: throw Unplaced("no type is written `(\(node.word) …)`", at: node.offset)
        }
    }

    private func array(_ node: Node, depth: Int) throws -> String {
        "\(TypeSpelling.array)<\(try spelled(node.one(), depth: depth + 1))>"
    }

    private func dictionary(_ node: Node, depth: Int) throws -> String {
        guard node.operands.count == 2 else {
            throw Unplaced("`dictionary` holds its key's type and its value's", at: node.offset)
        }

        let key = try spelled(node.operands[0], depth: depth + 1)
        let value = try spelled(node.operands[1], depth: depth + 1)

        return "\(TypeSpelling.dictionary)<\(key), \(value)>"
    }

    private func named(_ node: Node, depth: Int) throws -> String {
        let (applied, arguments) = try node.declared()

        guard ![TypeSpelling.array.spelling, TypeSpelling.dictionary.spelling].contains(applied) else {
            throw Unplaced("'\(applied)' is applied by its own node, `(\(applied.lowercased()) …)`", at: node.offset)
        }

        guard !arguments.isEmpty else {
            throw Unplaced("`named` holds a name and one type or more, and a name alone is written bare", at: node.offset)
        }

        let spelled = try arguments.map { argument in try self.spelled(argument, depth: depth + 1) }

        return "\(try name(node.operands[0]))<\(spelled.joined(separator: ", "))>"
    }

    private func nullable(_ node: Node, depth: Int) throws -> String {
        let inner = try node.one()

        guard !["inout", "var"].contains(inner.word) else {
            throw Unplaced("a slot's mark stands outside `nullable`, `(\(inner.word ?? "") (nullable …))`", at: inner.offset)
        }

        let spelled = try spelled(inner, depth: depth + 1)

        return inner.word == "procedure" ? "(\(spelled))?" : "\(spelled)?"
    }

    private func composition(_ node: Node) throws -> String {
        let names = try node.operands.map(name)

        guard names.count > 1, Set(names).count == names.count else {
            throw Unplaced("`composition` holds two names or more, none of them twice", at: node.offset)
        }

        return names.joined(separator: " & ")
    }

    private func some(_ node: Node) throws -> String {
        let (_, bounds) = try node.declared()
        let named = try name(node.operands[0])

        guard named != TypeSpelling.selfType.spelling, !named.hasPrefix("\(TypeSpelling.selfType).") else {
            throw Unplaced("`Self` and what it holds are written bare, not under `some`", at: node.offset)
        }

        guard !bounds.isEmpty else { return "\(TypeSpelling.some) \(named)" }

        guard !named.contains(".") else {
            throw Unplaced("a bound stands on a type parameter's name, and '\(named)' is an associated type", at: node.offset)
        }

        return "\(TypeSpelling.some) \(named): \(try bounds.map(name).joined(separator: " & "))"
    }

    private func name(_ datum: Datum) throws -> String {
        let name = try Node.name(datum)

        guard name.rangeOfCharacter(from: Self.cut) == nil else {
            throw Unplaced("'\(name)' holds what a type's spelling is cut at, and names no type", at: datum.offset)
        }

        return name
    }

    // The parts are read without recursing, and the recursion into the types
    // they hold stands in a function of its own.
    private func procedure(_ node: Node, depth: Int) throws -> String {
        let shape = try self.shape(of: node)
        let parameters = try shape.parameters?.map { operand in try spelled(operand, depth: depth + 1) }
        let returns = try shape.returns.map { returns in try spelled(returns, depth: depth + 1) }

        return try spelling(shape.modifiers, parameters, shape.failing, returns, at: node.offset)
    }

    private func shape(of node: Node) throws -> (modifiers: String, parameters: [Datum]?, failing: String?, returns: Datum?) {
        var marks: Set<String> = []
        var parameters: [Datum]?
        var failing: String?
        var returns: Datum?

        for operand in node.operands {
            let part = try Node(operand)

            guard marks.insert(part.word).inserted else {
                throw Unplaced("`\(part.word)` is written twice", at: part.offset)
            }

            switch part.word {
            case "const", "isolated": try part.none()
            case "parameters": parameters = part.operands
            case "failing": failing = try self.failing(part)
            case "returns": returns = try part.one()
            default: throw Unplaced("a procedure type holds no `\(part.word)`", at: part.offset)
            }
        }

        let modifiers = [TypeSpelling.const, TypeSpelling.isolated]
            .filter { modifier in marks.contains(modifier.spelling) }
            .map { modifier in "\(modifier) " }
            .joined()

        return (modifiers, parameters, failing, returns)
    }

    private func spelling(
        _ modifiers: String,
        _ parameters: [String]?,
        _ failing: String?,
        _ returns: String?,
        at offset: Int?
    ) throws -> String {
        switch (parameters, returns) {
        case let (parameters?, returns?):
            return "\(modifiers)(\(parameters.joined(separator: ", ")))\(failing ?? "") -> \(returns)"

        case (nil, nil) where failing == nil && !modifiers.isEmpty:
            return "\(modifiers)\(TypeSpelling.procedure)"

        case (nil, nil) where failing == nil:
            throw Unplaced("`Procedure` is written bare", at: offset)

        default:
            throw Unplaced("a procedure type writes `parameters` and `returns` both, or neither and no `failing`", at: offset)
        }
    }

    // What stands between a procedure type's parameters and its arrow.
    private func failing(_ node: Node) throws -> String {
        if node.operands.count == 1, node.operands[0].word == Failing.anythingSpelling {
            try Node(node.operands[0]).none()

            return " \(TypeSpelling.throws)"
        }

        return " \(TypeSpelling.throws)(\(try node.operands.map(name).joined(separator: ", ")))"
    }

    // The node a spelling looks like, made without refusing: whatever it
    // makes is held to writing the spelling back, which is what refuses.
    private func parsed(_ text: Substring, depth: Int) -> Datum {
        guard depth <= Value.nestingBound else { return .name(String(text)) }

        return marked(text, depth: depth)
            ?? grouped(text, depth: depth)
            ?? modified(text, depth: depth)
            ?? optional(text, depth: depth)
            ?? some(text)
            ?? composition(text)
            ?? applied(text, depth: depth)
            ?? .name(String(text))
    }

    // `inout T` and `var T`.
    private func marked(_ text: Substring, depth: Int) -> Datum? {
        for (prefix, word) in [("\(TypeSpelling.inout) ", "inout"), ("\(TypeSpelling.variable) ", "var")] {
            if let rest = dropped(from: text, prefix) {
                return .node(word, [parsed(rest, depth: depth + 1)])
            }
        }

        return nil
    }

    // `(T)?`, a procedure type made optional as a whole.
    private func grouped(_ text: Substring, depth: Int) -> Datum? {
        guard text.first == "(", text.last == "?", closing(in: text) == text.index(text.endIndex, offsetBy: -2) else {
            return nil
        }

        return .node("nullable", [parsed(text.dropFirst().dropLast(2), depth: depth + 1)])
    }

    // A procedure type, its modifiers in front.
    private func modified(_ text: Substring, depth: Int) -> Datum? {
        var rest = text
        var modifiers: [Datum] = []

        for word in ["const", "isolated"] {
            if let after = dropped(from: rest, "\(word) ") {
                rest = after
                modifiers.append(.node(word))
            }
        }

        if rest == TypeSpelling.procedure.spelling, !modifiers.isEmpty {
            return .node("procedure", modifiers)
        }

        guard rest.first == "(" || !modifiers.isEmpty else { return nil }

        return procedure(rest, modifiers: modifiers, depth: depth) ?? .name(String(text))
    }

    private func optional(_ text: Substring, depth: Int) -> Datum? {
        guard text.last == "?" else { return nil }

        return .node("nullable", [parsed(text.dropLast(), depth: depth + 1)])
    }

    private func some(_ text: Substring) -> Datum? {
        guard let rest = dropped(from: text, "\(TypeSpelling.some) ") else { return nil }

        guard let colon = rest.range(of: ": ") else { return .node("some", [.name(String(rest))]) }

        let bounds = rest[colon.upperBound...].components(separatedBy: " & ").map(Datum.name)

        return .node("some", [.name(String(rest[..<colon.lowerBound]))] + bounds)
    }

    private func composition(_ text: Substring) -> Datum? {
        let joined = split(text, at: " & ")

        guard joined.count > 1 else { return nil }

        return .node("composition", joined.map { part in .name(String(part)) })
    }

    // A name applied to types in angle brackets.
    private func applied(_ text: Substring, depth: Int) -> Datum? {
        guard text.last == ">", let open = text.firstIndex(of: "<") else { return nil }

        let base = String(text[..<open])
        let inside = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let arguments = split(inside, at: ", ").map { argument in parsed(argument, depth: depth + 1) }

        switch (base, arguments.count) {
        case (TypeSpelling.array.spelling, 1): return .node("array", arguments)
        case (TypeSpelling.dictionary.spelling, 2): return .node("dictionary", arguments)
        default: return .node("named", [.name(base)] + arguments)
        }
    }

    private func procedure(_ text: Substring, modifiers: [Datum], depth: Int) -> Datum? {
        guard let (inside, failing, returns) = pieces(of: text) else { return nil }

        let parameters = inside.isEmpty ? [] : split(inside, at: ", ").map { argument in parsed(argument, depth: depth + 1) }

        return .node(
            "procedure",
            modifiers + [.node("parameters", parameters)] + (failing.map { failing in [failing] } ?? [])
                + [.node("returns", [parsed(returns, depth: depth + 1)])]
        )
    }

    // A procedure type's spelling cut into what its parentheses hold, what
    // it may fail with and what follows its arrow.
    private func pieces(of text: Substring) -> (inside: Substring, failing: Datum?, returns: Substring)? {
        guard text.first == "(", let close = closing(in: text) else { return nil }

        let inside = text[text.index(after: text.startIndex)..<close]
        let after = text[text.index(after: close)...]

        guard let arrow = split(after, at: " -> ").first.map(\.endIndex), arrow < after.endIndex else { return nil }

        let returns = after[after.index(arrow, offsetBy: 4)...]

        switch after[..<arrow] {
        case "":
            return (inside, nil, returns)

        case " \(TypeSpelling.throws)":
            return (inside, .node("failing", [.node(Failing.anythingSpelling)]), returns)

        case let thrown:
            guard let listed = dropped(from: thrown, " \(TypeSpelling.throws)("), listed.last == ")" else { return nil }

            let names = listed.dropLast()

            return (inside, .node("failing", names.isEmpty ? [] : names.components(separatedBy: ", ").map(Datum.name)), returns)
        }
    }

    // The text after a prefix it begins with, nil where it does not.
    private func dropped(from text: Substring, _ prefix: String) -> Substring? {
        guard text.hasPrefix(prefix) else { return nil }

        return text.dropFirst(prefix.count)
    }

    // The parenthesis closing the one the text opens with.
    private func closing(in text: Substring) -> Substring.Index? {
        var depth = 0

        for index in text.indices {
            switch text[index] {
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

    // The text cut at each separator standing outside every bracket and
    // parenthesis. The `>` of an arrow closes nothing.
    private func split(_ text: Substring, at separator: String) -> [Substring] {
        var parts: [Substring] = []
        var depth = 0
        var start = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            if depth == 0, text[index...].hasPrefix(separator) {
                parts.append(text[start..<index])
                index = text.index(index, offsetBy: separator.count)
                start = index

                continue
            }

            switch text[index] {
            case "<", "(":
                depth += 1

            case ">" where index == text.startIndex || text[text.index(before: index)] != "-":
                depth -= 1

            case ")":
                depth -= 1

            default:
                break
            }

            index = text.index(after: index)
        }

        return parts + [text[start...]]
    }
}
