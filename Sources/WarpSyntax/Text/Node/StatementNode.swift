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
//   (switch t (case c (bind f x) (then …)) (default …))
//                                      { switch: { of: t, cases: { c: { binds: { f: "x" }, then } }, default } }
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
        SwitchForm.key,
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

    // What a switch takes apart, which stands by position before its arms,
    // and the keys its arms and its `default` stand under.
    private static let switched = SwitchForm.CodingKeys.of.name.spelling
    private static let cases = SwitchForm.CodingKeys.cases.name.spelling
    private static let otherwise = SwitchForm.CodingKeys.default.name.spelling

    // The word an arm is written with, and the words of its parts.
    private static let arm = "case"
    private static let bind = "bind"
    private static let binds = ArmReader.CodingKeys.binds.name.spelling
    private static let then = ArmReader.CodingKeys.then.name.spelling

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
            try keyed.write(try bound(held), under: StatementReader.valueKey.spelling, at: held.offset)
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

    // A list of statements, as a construct's parts hold them.
    func value(of statements: ArraySlice<Datum>) throws -> Value {
        .array(try statements.map { statement in try value(of: statement) })
    }

    func data(of statements: Value, as place: String) throws -> [Datum] {
        try Subtree(statements, as: place).list().map(datum(of:))
    }

    // MARK: - Private
    // What a statement's value is: a construct, or an expression.
    private func bound(_ datum: Datum) throws -> Value {
        guard let word = datum.word, Self.constructs.contains(word) else {
            return try ExpressionNode().value(of: datum)
        }

        return .dictionary([Name(normal: word): try construct(Node(datum))])
    }

    private func construct(_ node: Node) throws -> Value {
        switch node.word {
        case ReturnForm.key.spelling:
            return try returned(node)

        case BreakForm.key.spelling, ContinueForm.key.spelling:
            return node.operands.isEmpty ? .null : .string(try Node.name(node.one()))

        case UnwrapForm.key.spelling:
            return try unwrapped(node)

        case SwitchForm.key.spelling:
            return try switched(node)

        default:
            return try keyedParts(node, node.operands[...])
        }
    }

    // An unwrap: what it takes apart, and then its ways under keys.
    private func unwrapped(_ node: Node) throws -> Value {
        guard let subject = node.operands.first else {
            throw TextRefused("`\(node.word)` begins with what it takes apart", at: node.offset)
        }

        var keyed = Keyed()

        try keyed.write(try ExpressionNode().value(of: subject), under: Self.unwrapped, at: subject.offset)

        return try keyedParts(node, node.operands.dropFirst(), adding: keyed)
    }

    // A switch: what it takes apart, whatever word it begins with, then its
    // arms, each under its case, and its `default`.
    private func switched(_ node: Node) throws -> Value {
        guard let subject = node.operands.first else {
            throw TextRefused("`\(node.word)` begins with what it takes apart", at: node.offset)
        }

        var keyed = Keyed()

        try keyed.write(try ExpressionNode().value(of: subject), under: Self.switched, at: subject.offset)
        keyed.holdDictionary(Self.cases)

        for operand in node.operands.dropFirst() {
            let part = try Node(operand)

            switch part.word {
            case Self.arm:
                let (label, parts) = try part.declared()

                try keyed.write(try arm(parts), named: label, under: Self.cases, at: part.offset)

            case Self.otherwise:
                try keyed.write(try value(of: part.operands[...]), under: Self.otherwise, at: part.offset)

            default:
                throw TextRefused("`\(node.word)` holds no `\(part.word)`", at: part.offset)
            }
        }

        return try keyed.value()
    }

    // An arm: the fields it binds, each `(bind field name)`, and its `then`.
    private func arm(_ parts: ArraySlice<Datum>) throws -> Value {
        var keyed = Keyed()

        for operand in parts {
            let part = try Node(operand)

            switch part.word {
            case Self.bind:
                let (field, bound) = try part.named()

                try keyed.write(.string(try Node.name(bound)), named: field, under: Self.binds, at: part.offset)

            case Self.then:
                try keyed.write(try value(of: part.operands[...]), under: Self.then, at: part.offset)

            default:
                throw TextRefused("an arm holds no `\(part.word)`", at: part.offset)
            }
        }

        return try keyed.value()
    }

    // What a `return` hands back. Null is written by leaving the operand
    // out, so `(return null)` is a second text of `(return)`.
    private func returned(_ node: Node) throws -> Value {
        guard let operand = node.operands.first else { return .null }

        guard case .null = operand.form else { return try ExpressionNode().value(of: node.one()) }

        throw TextRefused("`(return)` returns null, and is the one text of it", at: operand.offset)
    }

    // A construct holding parts under keys: a conditional, a loop, a
    // try, and an unwrap's ways after what it takes apart, which `keyed`
    // holds already.
    private func keyedParts(
        _ node: Node,
        _ operands: ArraySlice<Datum>,
        adding keyed: Keyed = Keyed()
    ) throws -> Value {
        var keyed = keyed
        let parts = Self.parts[node.word] ?? []

        for operand in operands {
            let part = try Node(operand)

            guard let (_, holding) = parts.first(where: { key, _ in key == part.word }) else {
                throw TextRefused("`\(node.word)` holds no `\(part.word)`", at: part.offset)
            }

            let held: Value = switch holding {
            case .expression: try ExpressionNode().value(of: part.one())
            case .statements: try value(of: part.operands[...])
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

        case SwitchForm.key.spelling:
            return try datum(switch: body)

        default:
            var fields = try Fields(body, as: "a `\(word)`")

            return .block(word, try parts(of: &fields, in: word))
        }
    }

    // A switch: its subject, its arms by case name, then its `default`.
    private func datum(switch body: Value) throws -> Datum {
        var fields = try Fields(body, as: "a `\(SwitchForm.key)`")

        guard let subject = fields.take(Self.switched) else {
            throw TextRefused(
                "a `\(SwitchForm.key)` takes apart what it holds under `\(Self.switched)`, and this holds nothing there"
            )
        }

        let arms: [Datum] = try fields.take(Self.cases).map { cases in
            try Subtree(cases, as: "a switch's arms").entries().map { label, arm in
                Datum.block(Self.arm, [.name(label)] + (try datum(arm: arm)))
            }
        } ?? []
        let otherwise = try fields.take(Self.otherwise).map { statements in
            Datum.block(Self.otherwise, try data(of: statements, as: "a `\(Self.otherwise)`"))
        }

        try fields.finish()

        return .block(SwitchForm.key.spelling, [try ExpressionNode().datum(of: subject)] + arms + (otherwise.map { [$0] } ?? []))
    }

    // An arm's parts: its binds by field name, then its `then`.
    private func datum(arm: Value) throws -> [Datum] {
        var fields = try Fields(arm, as: "an arm")
        let binds: [Datum] = try fields.take(Self.binds).map { written in
            let entries = try Subtree(written, as: "an arm's binds").entries()

            guard !entries.isEmpty else {
                throw TextRefused("an arm binding nothing writes no `\(Self.binds)`, and no node writes it empty")
            }

            return try entries.map { field, bound in
                Datum.node(Self.bind, [.name(field), .name(try Subtree(bound, as: "a bound name").string())])
            }
        } ?? []
        let then = try fields.take(Self.then).map { statements in
            Datum.block(Self.then, try data(of: statements, as: "a `\(Self.then)`"))
        }

        try fields.finish()

        return binds + (then.map { [$0] } ?? [])
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
