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
//   e                                  { value e }
//   (let x (type Int) v)               { let "x", type "Int", value v }
//   (var x)  (var x v)                 { var "x" }, { var "x", value v }
//   (set (path a (field b)) v)         { set "a.b", value v }
//   (conditional (when c) (then …) (else …))
//   (loop (while c) (body …))
//   (attempt (body …) (result e) (rescue (body …) (result e)))
//   (return)  (return e)  (break)  (break w)  (continue)  (continue w)
struct StatementNode {
    // What a construct's part holds.
    private enum Part {
        case expression
        case statements
        case rescue
    }

    // MARK: - Property
    private static let bindings: [String] = StatementReader.NamingKeys.allCases.map(\.name.spelling)

    private static let constructs: Set<String> = [
        ConditionalForm.key,
        LoopForm.key,
        AttemptForm.key,
        ReturnForm.key,
        BreakForm.key,
        ContinueForm.key
    ]
    .reduce(into: []) { words, key in words.insert(key.spelling) }

    // The parts a construct holding parts holds, in the order they are
    // written, and an attempt's rescue among them.
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
        AttemptForm.key.spelling: [
            (AttemptForm.CodingKeys.body.name.spelling, .statements),
            (AttemptForm.CodingKeys.result.name.spelling, .expression),
            (AttemptForm.CodingKeys.rescue.name.spelling, .rescue)
        ],
        AttemptForm.CodingKeys.rescue.name.spelling: [
            (BlockReader.CodingKeys.body.name.spelling, .statements),
            (BlockReader.CodingKeys.result.name.spelling, .expression)
        ]
    ]

    // MARK: - Initializer
    // MARK: - Public
    func value(of datum: Datum) throws -> Value {
        guard let word = datum.word, Self.bindings.contains(word) else {
            return .dictionary([StatementReader.valueKey: try bound(datum)])
        }

        let node = try Node(datum)
        var keyed = Keyed()
        var operands = node.operands[...]

        guard let named = operands.popFirst() else {
            throw Unplaced("`\(word)` begins with what it binds", at: node.offset)
        }

        let binding = word == StatementReader.NamingKeys.assignment.name.spelling
            ? try PathNode().text(of: named)
            : try Node.name(named)

        try keyed.write(.string(binding), under: word, at: node.offset)

        if let typed = operands.first, typed.word == StatementReader.typeKey.spelling {
            guard word != StatementReader.NamingKeys.assignment.name.spelling else {
                throw Unplaced("a `set` writes no type", at: typed.offset)
            }

            operands.removeFirst()

            try keyed.write(.string(try TypeNode().text(of: Node(typed).one())), under: StatementReader.typeKey.spelling, at: typed.offset)
        }

        if let held = operands.popFirst() {
            try keyed.write(try bound(held), under: StatementReader.valueKey.spelling, at: held.offset)
        } else if word != StatementReader.NamingKeys.variable.name.spelling {
            throw Unplaced("a `\(word)` writes a value", at: node.offset)
        }

        if let extra = operands.first {
            throw Unplaced("`\(word)` holds what it binds, a type and a value, and nothing after", at: extra.offset)
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
                throw EncodingRefused("a statement that binds nothing is a value alone, and no node writes this one")
            }

            return try datum(bound: held)
        }

        guard bindings.count == 1 else {
            throw EncodingRefused("a statement binds once, and this one writes \(bindings.map { word, _ in "`\(word)`" }.joined(separator: " and "))")
        }

        var operands: [Datum]

        if word == StatementReader.NamingKeys.assignment.name.spelling {
            guard type == nil else {
                throw EncodingRefused("a `set` writes no type, and no node writes one beside it")
            }

            operands = [try PathNode().datum(of: try Fields.text(binding, as: "what a `set` writes"))]
        } else {
            operands = [.name(try Fields.text(binding, as: "what a `\(word)` binds"))]
        }

        if let type {
            operands.append(.node(StatementReader.typeKey.spelling, [try TypeNode().datum(of: try Fields.text(type, as: "a binding's type"))]))
        }

        if let held {
            operands.append(try datum(bound: held))
        } else if word != StatementReader.NamingKeys.variable.name.spelling {
            throw EncodingRefused("a `\(word)` writes a value, and no node writes one without it")
        }

        return .node(word, operands)
    }

    // A list of statements, as a block's parts hold them.
    func value(of statements: ArraySlice<Datum>) throws -> Value {
        .array(try statements.map(value(of:)))
    }

    func data(of statements: Value, as place: String) throws -> [Datum] {
        try Fields.list(statements, as: place).map(datum(of:))
    }

    // MARK: - Private
    // What a statement's value is: a construct, or an expression.
    private func bound(_ datum: Datum) throws -> Value {
        guard let word = datum.word, Self.constructs.contains(word) else {
            return try ExpressionNode().value(of: datum)
        }

        let node = try Node(datum)

        return .dictionary([Name(normal: word): try construct(node)])
    }

    private func construct(_ node: Node) throws -> Value {
        switch node.word {
        case ReturnForm.key.spelling:
            return node.operands.isEmpty ? .null : try ExpressionNode().value(of: node.one())

        case BreakForm.key.spelling, ContinueForm.key.spelling:
            return node.operands.isEmpty ? .null : .string(try Node.name(node.one()))

        default:
            return try block(node)
        }
    }

    // A construct holding parts under keys: a conditional, a loop, an
    // attempt and its rescue.
    private func block(_ node: Node) throws -> Value {
        var keyed = Keyed()
        let parts = Self.parts[node.word] ?? []

        for operand in node.operands {
            let part = try Node(operand)

            guard let (_, holding) = parts.first(where: { key, _ in key == part.word }) else {
                throw Unplaced("`\(node.word)` holds no `\(part.word)`", at: part.offset)
            }

            let held: Value = switch holding {
            case .expression: try ExpressionNode().value(of: part.one())
            case .statements: try value(of: part.operands[...])
            case .rescue: try block(part)
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
            return .node(word, body == .null ? [] : [.name(try Fields.text(body, as: "what a `\(word)` leaves"))])

        default:
            return .block(word, try parts(of: body, in: word))
        }
    }

    private func parts(of body: Value, in word: String) throws -> [Datum] {
        var fields = try Fields(body, as: "a `\(word)`")

        let parts = try (Self.parts[word] ?? []).compactMap { key, holding -> Datum? in
            guard let held = fields.take(key) else { return nil }

            return switch holding {
            case .expression: .node(key, [try ExpressionNode().datum(of: held)])
            case .statements: .block(key, try data(of: held, as: "a `\(key)`"))
            case .rescue: .block(key, try self.parts(of: held, in: key))
            }
        }

        try fields.finish()

        return parts
    }
}
