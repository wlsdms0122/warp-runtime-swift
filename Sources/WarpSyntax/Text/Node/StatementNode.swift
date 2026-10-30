//
//  StatementNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A statement as a node, and the tree it writes. An expression where a
// statement stands is the statement of that value, and a binding's value is
// an expression or a construct.
//
//   e                                  { value: e }
//   (let x (type Int) v)               { let: "x", type: "Int", value: v }
//   (var x)  (var x v)                 { var: "x" }, { var: "x", value: v }
//   (set (path a (field b)) v)         { set: "a.b", value: v }
//   (conditional (when c) (then …) (else …))
//   (loop (while c) (body …))
//   (try (body …) (catch …))
//   (unwrap o (then …) (else …))         { unwrap: { of: o, then, else } }
//   (return)  (return e)  (break)  (break w)  (continue)  (continue w)
struct StatementNode {
    // What a construct's part holds.
    private enum Part {
        case expression
        case statements
    }

    // MARK: - Property
    private static let bindings: [String] = StatementReader.NamingKeys.allCases.map(\.name.spelling)

    private static let constructs: Set<String> = [
        ConditionalForm.key,
        LoopForm.key,
        TryForm.key,
        UnwrapForm.key,
        ReturnForm.key,
        BreakForm.key,
        ContinueForm.key
    ]
    .reduce(into: []) { words, key in words.insert(key.spelling) }

    // The parts a construct holding parts holds, in the order they are
    // written.
    private static let parts: [String: [(key: String, part: Part)]] = [
        ConditionalForm.key.spelling: [
            (ConditionalForm.CodingKeys.when.name.spelling, .expression),
            (ConditionalForm.CodingKeys.then.name.spelling, .statements),
            (ConditionalForm.CodingKeys.else.name.spelling, .statements)
        ],
        LoopForm.key.spelling: [
            (LoopForm.CodingKeys.while.name.spelling, .expression),
            (LoopForm.CodingKeys.body.name.spelling, .statements)
        ],
        TryForm.key.spelling: [
            (TryForm.CodingKeys.body.name.spelling, .statements),
            (TryForm.CodingKeys.catch.name.spelling, .statements)
        ],
        UnwrapForm.key.spelling: [
            (UnwrapForm.CodingKeys.then.name.spelling, .statements),
            (UnwrapForm.CodingKeys.else.name.spelling, .statements)
        ]
    ]

    // What an unwrap takes apart, which stands by position before its ways.
    private static let unwrapped = UnwrapForm.CodingKeys.of.name.spelling

    // MARK: - Initializer
    // MARK: - Public
    // A statement is a mapping, one container on from the `depth` around it.
    func value(of datum: Datum, within depth: Int) throws -> Value {
        let inside = try Node.opening(1, within: depth, at: datum.offset)

        guard let word = datum.word, Self.bindings.contains(word) else {
            return .dictionary([StatementReader.valueKey: try bound(datum, within: inside)])
        }

        let node = try Node(datum)
        var keyed = Keyed()
        var operands = node.operands[...]

        guard let named = operands.popFirst() else {
            throw TextRefused("`\(word)` begins with what it binds", at: node.offset)
        }

        let binding = word == StatementReader.NamingKeys.assignment.name.spelling
            ? try PathNode().text(of: named)
            : try Node.name(named)

        try keyed.write(.string(binding), under: word, at: node.offset)

        if let typed = operands.first, typed.word == StatementReader.typeKey.spelling {
            operands.removeFirst()

            try keyed.write(.string(try TypeNode().text(of: Node(typed).one())), under: StatementReader.typeKey.spelling, at: typed.offset)
        }

        if let held = operands.popFirst() {
            try keyed.write(try bound(held, within: inside), under: StatementReader.valueKey.spelling, at: held.offset)
        }

        if let extra = operands.first {
            throw TextRefused("`\(word)` holds what it binds, a type and a value, and nothing after", at: extra.offset)
        }

        return try keyed.value()
    }

    func datum(of value: Value) throws -> Datum {
        var fields = try Fields(value, as: "a statement")
        let bindings = Self.bindings.compactMap { word in fields.take(word).map { binding in (word, binding) } }
        let type = fields.take(StatementReader.typeKey.spelling)
        let held = fields.take(StatementReader.valueKey.spelling)

        try fields.finish()

        guard let (word, binding) = bindings.first else {
            guard let held, type == nil else {
                throw TextRefused("a statement that binds nothing is a value alone, and no node writes this one")
            }

            return try datum(bound: held)
        }

        guard bindings.count == 1 else {
            throw TextRefused("a statement binds once, and this one writes \(bindings.map { word, _ in "`\(word)`" }.joined(separator: " and "))")
        }

        var operands: [Datum]

        if word == StatementReader.NamingKeys.assignment.name.spelling {
            operands = [try PathNode().datum(of: try Subtree(binding, as: "what a `set` writes").string())]
        } else {
            operands = [.name(try Subtree(binding, as: "what a `\(word)` binds").string())]
        }

        if let type {
            operands.append(.node(StatementReader.typeKey.spelling, [try TypeNode().datum(of: try Subtree(type, as: "a binding's type").string())]))
        }

        if let held {
            operands.append(try datum(bound: held))
        }

        return .node(word, operands)
    }

    // A list of statements, as a construct's parts hold them, written in
    // the node at `offset`.
    func value(of statements: ArraySlice<Datum>, within depth: Int, at offset: Int?) throws -> Value {
        let inside = try Node.opening(1, within: depth, at: offset)

        return .array(try statements.map { statement in try value(of: statement, within: inside) })
    }

    func data(of statements: Value, as place: String) throws -> [Datum] {
        try Subtree(statements, as: place).list().map(datum(of:))
    }

    // MARK: - Private
    // What a statement's value is: a construct, or an expression.
    private func bound(_ datum: Datum, within depth: Int) throws -> Value {
        guard let word = datum.word, Self.constructs.contains(word) else {
            return try ExpressionNode().value(of: datum, within: depth)
        }

        let node = try Node(datum)
        let inside = try Node.opening(1, within: depth, at: node.offset)

        return .dictionary([Name(normal: word): try construct(node, within: inside)])
    }

    private func construct(_ node: Node, within depth: Int) throws -> Value {
        switch node.word {
        case ReturnForm.key.spelling:
            return try returned(node, within: depth)

        case BreakForm.key.spelling, ContinueForm.key.spelling:
            return node.operands.isEmpty ? .null : .string(try Node.name(node.one()))

        case UnwrapForm.key.spelling:
            return try unwrapped(node, within: depth)

        default:
            return try keyedParts(node, node.operands[...], within: depth)
        }
    }

    // An unwrap: what it takes apart, and then its ways under keys.
    private func unwrapped(_ node: Node, within depth: Int) throws -> Value {
        guard let subject = node.operands.first else {
            throw TextRefused("`\(node.word)` begins with what it takes apart", at: node.offset)
        }

        let inside = try Node.opening(1, within: depth, at: node.offset)
        var keyed = Keyed()

        try keyed.write(try ExpressionNode().value(of: subject, within: inside), under: Self.unwrapped, at: subject.offset)

        return try keyedParts(node, node.operands.dropFirst(), adding: keyed, within: depth)
    }

    // What a `return` hands back. Null is written by leaving the operand
    // out, so `(return null)` is a second text of `(return)`.
    private func returned(_ node: Node, within depth: Int) throws -> Value {
        guard let operand = node.operands.first else { return .null }

        guard case .null = operand.form else { return try ExpressionNode().value(of: node.one(), within: depth) }

        throw TextRefused("`(return)` returns null, and is the one text of it", at: operand.offset)
    }

    // A construct holding parts under keys: a conditional, a loop, a
    // try, and an unwrap's ways after what it takes apart, which `keyed`
    // holds already.
    private func keyedParts(
        _ node: Node,
        _ operands: ArraySlice<Datum>,
        adding keyed: Keyed = Keyed(),
        within depth: Int
    ) throws -> Value {
        let inside = try Node.opening(1, within: depth, at: node.offset)
        var keyed = keyed
        let parts = Self.parts[node.word] ?? []

        for operand in operands {
            let part = try Node(operand)

            guard let (_, holding) = parts.first(where: { key, _ in key == part.word }) else {
                throw TextRefused("`\(node.word)` holds no `\(part.word)`", at: part.offset)
            }

            let held: Value = switch holding {
            case .expression: try ExpressionNode().value(of: part.one(), within: inside)
            case .statements: try value(of: part.operands[...], within: inside, at: part.offset)
            }

            try keyed.write(held, under: part.word, at: part.offset)
        }

        return try keyed.value()
    }

    private func datum(bound value: Value) throws -> Datum {
        guard
            case let .dictionary(held) = value,
            held.count == 1,
            case let .string(word) = held.entries[0].key,
            Self.constructs.contains(word)
        else {
            return try ExpressionNode().datum(of: value)
        }

        let body = held.entries[0].value

        switch word {
        case ReturnForm.key.spelling:
            return .node(word, body == .null ? [] : [try ExpressionNode().datum(of: body)])

        case BreakForm.key.spelling, ContinueForm.key.spelling:
            return .node(word, body == .null ? [] : [.name(try Subtree(body, as: "what a `\(word)` leaves").string())])

        case UnwrapForm.key.spelling:
            var fields = try Fields(body, as: "a `\(word)`")

            guard let subject = fields.take(Self.unwrapped) else {
                throw TextRefused("a `\(word)` takes apart what it holds under `\(Self.unwrapped)`, and this holds nothing there")
            }

            return .block(word, [try ExpressionNode().datum(of: subject)] + (try parts(of: &fields, in: word)))

        default:
            var fields = try Fields(body, as: "a `\(word)`")

            return .block(word, try parts(of: &fields, in: word))
        }
    }

    private func parts(of fields: inout Fields, in word: String) throws -> [Datum] {
        let parts = try (Self.parts[word] ?? []).compactMap { key, holding -> Datum? in
            guard let held = fields.take(key) else { return nil }

            return switch holding {
            case .expression: .node(key, [try ExpressionNode().datum(of: held)])
            case .statements: .block(key, try data(of: held, as: "a `\(key)`"))
            }
        }

        try fields.finish()

        return parts
    }
}
