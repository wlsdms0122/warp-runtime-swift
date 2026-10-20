//
//  TypeNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A type as a node, and the text a tree holds for it: a node is a type's
// syntax, `TypeSyntax`, and its text that syntax's spelling, read back by
// `TypeParser`. One type, one node: a node is the one its text reads as, so a
// text read back is the node it was written as.
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
    // MARK: - Initializer
    // MARK: - Public
    // The text a node writes, where the node is the one that text reads as.
    func text(of datum: Datum) throws -> String {
        let text = try syntax(of: datum, depth: 0).spelling

        guard
            let read = (try? TypeParser().parse(text)).flatMap(self.datum(of:)),
            try DatumWriter().line(of: read) == DatumWriter().line(of: datum)
        else {
            throw Unplaced("'\(text)' is written as another node, and is one type", at: datum.offset)
        }

        return text
    }

    // The node a tree's text is, where a node writes that text back.
    func datum(of text: String) throws -> Datum {
        let syntax: TypeSyntax

        do {
            syntax = try TypeParser().parse(text)
        } catch let refusal as TypeSyntaxError {
            throw Unplaced("the type is written '\(text)', which no node writes: \(refusal.message)")
        }

        guard let datum = datum(of: syntax), (try? self.text(of: datum)) == text else {
            throw Unplaced("the type is written '\(text)', which no node writes")
        }

        return datum
    }

    // MARK: - Private
    // A dispatcher and a function a word, so a recursion through a type
    // spends one word's frame a level. A type's nodes nest no deeper than a
    // tree may.
    private func syntax(of datum: Datum, depth: Int) throws -> TypeSyntax {
        guard depth <= Value.nestingBound else {
            throw Unplaced("the type nests deeper than a document may", at: datum.offset)
        }

        guard case .list = datum.form else { return .name(try Node.name(datum)) }

        let node = try Node(datum)

        switch node.word {
        case "array": return try array(node, depth: depth)
        case "dictionary": return try dictionary(node, depth: depth)
        case "named": return try named(node, depth: depth)
        case "nullable": return try nullable(node, depth: depth)
        case "composition": return try composition(node)
        case "some": return try some(node)
        case "inout": return try marked(.inout, node, depth: depth)
        case "var": return try marked(.variable, node, depth: depth)
        case "procedure": return try procedure(node, depth: depth)
        default: throw unwritten(node)
        }
    }

    private func unwritten(_ node: Node) -> Unplaced {
        Unplaced("no type is written `(\(node.word) …)`", at: node.offset)
    }

    private func composition(_ node: Node) throws -> TypeSyntax {
        .composition(try node.operands.map(Node.name))
    }

    private func array(_ node: Node, depth: Int) throws -> TypeSyntax {
        .applied(TypeSpelling.array.spelling, [try syntax(of: node.one(), depth: depth + 1)])
    }

    private func nullable(_ node: Node, depth: Int) throws -> TypeSyntax {
        .nullable(try syntax(of: node.one(), depth: depth + 1))
    }

    private func marked(_ mark: TypeSyntax.Mark, _ node: Node, depth: Int) throws -> TypeSyntax {
        .marked(mark, try syntax(of: node.one(), depth: depth + 1))
    }

    // Each of these, a level deeper.
    private func syntax(of operands: [Datum], depth: Int) throws -> [TypeSyntax] {
        var syntax: [TypeSyntax] = []

        for operand in operands {
            syntax.append(try self.syntax(of: operand, depth: depth + 1))
        }

        return syntax
    }

    private func dictionary(_ node: Node, depth: Int) throws -> TypeSyntax {
        guard node.operands.count == 2 else {
            throw Unplaced("`dictionary` holds its key's type and its value's", at: node.offset)
        }

        return .applied(TypeSpelling.dictionary.spelling, try syntax(of: node.operands, depth: depth))
    }

    private func named(_ node: Node, depth: Int) throws -> TypeSyntax {
        let (applied, arguments) = try node.declared()

        return .applied(applied, try syntax(of: Array(arguments), depth: depth))
    }

    private func some(_ node: Node) throws -> TypeSyntax {
        let (named, bound) = try node.declared()

        return .parameter(named, bound: bound.isEmpty ? nil : try bound.map(Node.name))
    }

    // The parts are read without recursing, and the recursion into the types
    // they hold stands in a function of its own.
    private func procedure(_ node: Node, depth: Int) throws -> TypeSyntax {
        let (modifiers, parameters, throwing, returns) = try signature(of: node)
        var written = TypeSyntax.name(TypeSpelling.procedure.spelling)

        if let parameters, let returns {
            written = .procedure(
                try syntax(of: parameters, depth: depth),
                throwing: throwing,
                returns: try syntax(of: returns, depth: depth + 1)
            )
        }

        return modifiers.isEmpty ? written : .modified(modifiers, written)
    }

    // A procedure type's modifiers in the order written, and its parameters,
    // what it may fail with and what it answers, where it writes them.
    private func signature(
        of node: Node
    ) throws -> ([TypeSyntax.Modifier], parameters: [Datum]?, throwing: TypeSyntax.Throwing?, returns: Datum?) {
        var modifiers: [TypeSyntax.Modifier] = []
        var parts: [String: Node] = [:]

        for operand in node.operands {
            let part = try Node(operand)

            if let modifier = TypeSyntax.Modifier.allCases.first(where: { modifier in modifier.word.spelling == part.word }) {
                try part.none()
                modifiers.append(modifier)

                continue
            }

            switch part.word {
            case "parameters", "failing", "returns":
                guard parts.updateValue(part, forKey: part.word) == nil else {
                    throw Unplaced("`\(part.word)` is written twice", at: part.offset)
                }

            default:
                throw Unplaced("a procedure type holds no `\(part.word)`", at: part.offset)
            }
        }

        guard (parts["parameters"] == nil) == (parts["returns"] == nil), parts["returns"] != nil || parts["failing"] == nil else {
            throw Unplaced("a procedure type writes `parameters` and `returns` both, or neither and no `failing`", at: node.offset)
        }

        return (modifiers, parts["parameters"]?.operands, try parts["failing"].map(throwing), try parts["returns"]?.one())
    }

    private func throwing(_ node: Node) throws -> TypeSyntax.Throwing {
        if node.operands.count == 1, node.operands[0].word == Failing.anythingSpelling {
            try Node(node.operands[0]).none()

            return .anything
        }

        return .these(try node.operands.map(Node.name))
    }

    // The node a syntax is written as, where one is. A dispatcher and a
    // function a form, as on the way in.
    private func datum(of syntax: TypeSyntax) -> Datum? {
        switch syntax {
        case let .name(name):
            return .name(name)

        case let .applied(name, arguments):
            return data(of: arguments).map { data in applied(name, data) }

        case let .nullable(inner):
            return held(by: "nullable", inner)

        case let .composition(names):
            return .node("composition", names.map(Datum.name))

        case let .parameter(name, bound):
            return .node("some", [.name(name)] + (bound ?? []).map(Datum.name))

        case let .marked(mark, inner):
            return held(by: mark.word.spelling, inner)

        case let .modified(modifiers, .procedure(parameters, throwing, returns)):
            return procedure(modifiers, parameters, throwing, returns)

        case let .modified(modifiers, inner):
            return modified(modifiers, inner)

        case let .procedure(parameters, throwing, returns):
            return procedure([], parameters, throwing, returns)
        }
    }

    private func data(of syntaxes: [TypeSyntax]) -> [Datum]? {
        var data: [Datum] = []

        for syntax in syntaxes {
            guard let datum = datum(of: syntax) else { return nil }

            data.append(datum)
        }

        return data
    }

    private func held(by word: String, _ inner: TypeSyntax) -> Datum? {
        datum(of: inner).map { datum in .node(word, [datum]) }
    }

    private func applied(_ name: String, _ data: [Datum]) -> Datum {
        switch (name, data.count) {
        case (TypeSpelling.array.spelling, 1): .node("array", data)
        case (TypeSpelling.dictionary.spelling, 2): .node("dictionary", data)
        default: .node("named", [.name(name)] + data)
        }
    }

    // A modifier is written on a procedure type's node, so modifiers on
    // anything but a procedure type have a node only on `Procedure`.
    private func modified(_ modifiers: [TypeSyntax.Modifier], _ inner: TypeSyntax) -> Datum? {
        guard case .name(TypeSpelling.procedure.spelling) = inner else { return nil }

        return .node("procedure", modifiers.map { modifier in Datum.node(modifier.word.spelling) })
    }

    // The recursion into the types a procedure type holds stands here, and
    // the node is put together in a function of its own.
    private func procedure(
        _ modifiers: [TypeSyntax.Modifier],
        _ parameters: [TypeSyntax],
        _ throwing: TypeSyntax.Throwing?,
        _ returns: TypeSyntax
    ) -> Datum? {
        guard let parameters = data(of: parameters), let returns = datum(of: returns) else { return nil }

        return procedure(modifiers, parameters, throwing, returns)
    }

    private func procedure(
        _ modifiers: [TypeSyntax.Modifier],
        _ parameters: [Datum],
        _ throwing: TypeSyntax.Throwing?,
        _ returns: Datum
    ) -> Datum {
        let failing: [Datum] = switch throwing {
        case nil: []
        case .anything: [.node("failing", [.node(Failing.anythingSpelling)])]
        case let .these(names): [.node("failing", names.map(Datum.name))]
        }

        return .node(
            "procedure",
            modifiers.map { modifier in Datum.node(modifier.word.spelling) } + [.node("parameters", parameters)] + failing
                + [.node("returns", [returns])]
        )
    }
}
