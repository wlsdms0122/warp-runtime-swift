//
//  ExpressionNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// An expression as a node, and the tree it writes where a value stands.
//
//   null true 1 1.5 "hi" x"6a"         the scalar
//   x  (path a (field b))              { ref "a.b" }
//   (call App.g 1 x)                   { call { procedure "App.g", arguments [1, { ref "x" }] } }
//   (apply f 1)                        { call { procedure { ref "f" }, arguments [1] } }
//   (as e Int)  (as? e Int)            { as { of, type "Int" } }, { as? { … } }
//   (array 1 x)                        [1, { ref "x" }]
//   (dictionary (entry "a" 1))         { dictionary [["a", 1]] }
//   (struct (field x 1))               { struct { x 1 } }
//   (struct App.Point (field x 1))     the struct value, its fields read as data
//   (closure …)                        { closure { … } }
struct ExpressionNode {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A dispatcher and a function a word, so a recursion through an
    // expression spends one word's frame a level and not every word's.
    func value(of datum: Datum) throws -> Value {
        switch datum.form {
        case .null, .bool, .int, .double, .text, .bytes:
            return try DataNode().value(of: datum)

        case .name:
            return try reference(datum)

        case .list:
            break
        }

        let node = try Node(datum)

        switch node.word {
        case "path": return try reference(datum)
        case "call": return try call(node)
        case "apply": return try apply(node)
        case "as", "as?": return try cast(node)
        case "array": return try array(node)
        case "dictionary": return try dictionary(node)
        case "struct": return try `struct`(node, datum)
        case "closure": return try closure(node)
        default: throw unknown(node)
        }
    }

    func datum(of value: Value) throws -> Datum {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes, .struct:
            return try DataNode().datum(of: value)

        case let .array(elements):
            return try array(elements)

        case .procedure:
            throw TextRefused("a procedure closed over a scope is not data, and a document holds data")

        case .dictionary:
            break
        }

        let (tag, held) = try tagged(value)

        switch tag {
        case .reference: return try PathNode().datum(of: try Subtree(held, as: "a reference").text())
        case .call: return try call(held)
        case .cast, .optionalCast: return try cast(held, as: tag)
        case .dictionary: return try dictionary(held)
        case .struct: return try `struct`(held)
        case .closure: return .block("closure", try ProcedureNode().parts(of: held))
        }
    }

    // MARK: - Private
    private func reference(_ datum: Datum) throws -> Value {
        tagged(.reference, .string(try PathNode().text(of: datum)))
    }

    private func call(_ node: Node) throws -> Value {
        let (callee, arguments) = try node.declared()

        return tagged(.call, try call(.string(callee), handing: arguments))
    }

    private func apply(_ node: Node) throws -> Value {
        guard let callee = node.operands.first else {
            throw TextRefused("`apply` holds the value it calls, then what it hands", at: node.offset)
        }

        if case .text = callee.form {
            throw TextRefused("text under `procedure` names a declaration, and a call of one is `(call …)`", at: callee.offset)
        }

        return tagged(.call, try call(try value(of: callee), handing: node.operands.dropFirst()))
    }

    private func cast(_ node: Node) throws -> Value {
        guard node.operands.count == 2 else {
            throw TextRefused("`\(node.word)` holds what it casts, then the type", at: node.offset)
        }

        return tagged(
            node.word == ExpressionTag.cast.rawValue ? .cast : .optionalCast,
            .dictionary([
                ExpressionReader.subjectKey: try value(of: node.operands[0]),
                ExpressionReader.typeKey: .string(try TypeNode().text(of: node.operands[1]))
            ])
        )
    }

    private func array(_ node: Node) throws -> Value {
        .array(try node.operands.map(value(of:)))
    }

    private func dictionary(_ node: Node) throws -> Value {
        tagged(.dictionary, .array(try node.operands.map(entry)))
    }

    private func entry(_ datum: Datum) throws -> Value {
        let entry = try Node(datum)

        guard entry.word == "entry", entry.operands.count == 2 else {
            throw TextRefused("a map holds `(entry key value)`", at: datum.offset)
        }

        return .array([try value(of: entry.operands[0]), try value(of: entry.operands[1])])
    }

    // A struct with a name is a value, so what stands inside it is data.
    private func `struct`(_ node: Node, _ datum: Datum) throws -> Value {
        if let first = node.operands.first, !first.isList {
            return try DataNode().value(of: datum)
        }

        var fields = Keyed()

        for operand in node.operands {
            let field = try Node(operand)

            guard field.word == "field" else {
                throw TextRefused("a struct holds `(field name value)`", at: operand.offset)
            }

            let (name, held) = try field.named()

            try fields.write(try value(of: held), under: name, at: field.offset)
        }

        return tagged(.struct, try fields.value())
    }

    private func closure(_ node: Node) throws -> Value {
        tagged(.closure, try ProcedureNode().value(of: node.operands[...]))
    }

    private func unknown(_ node: Node) -> TextRefused {
        TextRefused("no expression is written `(\(node.word) …)`", at: node.offset)
    }

    // The one tag a mapping where a value stands is an expression by, and
    // what it holds.
    private func tagged(_ value: Value) throws -> (ExpressionTag, Value) {
        let entries = try Subtree(value, as: "an expression").entries()

        guard entries.count == 1, let tag = ExpressionTag(rawValue: entries[0].key) else {
            throw TextRefused(
                "an expression is a mapping of one tag, and this one holds \(entries.map { entry in "`\(entry.key)`" }.joined(separator: ", "))"
            )
        }

        return (tag, entries[0].value)
    }

    private func array(_ elements: [Value]) throws -> Datum {
        .node("array", try elements.map(datum(of:)))
    }

    private func call(_ held: Value) throws -> Datum {
        var fields = try Fields(held, as: "a call")
        let callee = fields.take(CallForm.CodingKeys.procedure.name.spelling)
        var arguments: [Datum] = []

        if let handed = fields.take(CallForm.CodingKeys.arguments.name.spelling) {
            let list = try Subtree(handed, as: "a call's arguments").list()

            guard !list.isEmpty else {
                throw TextRefused("a call writes `arguments` where it hands something, and no node writes it empty")
            }

            arguments = try list.map(datum(of:))
        }

        try fields.finish()

        switch callee {
        case let .string(name)?:
            return .node("call", [.name(name)] + arguments)

        case let callee?:
            return .node("apply", [try datum(of: callee)] + arguments)

        case nil:
            throw TextRefused("a call names what it calls under `procedure`, and this one does not")
        }
    }

    private func cast(_ held: Value, as tag: ExpressionTag) throws -> Datum {
        var fields = try Fields(held, as: "a cast")

        guard
            let subject = fields.take(ExpressionReader.subjectKey.spelling),
            let type = fields.take(ExpressionReader.typeKey.spelling)
        else {
            throw TextRefused("a cast writes what it casts and the type, and no node writes one without both")
        }

        try fields.finish()

        return .node(tag.rawValue, [try datum(of: subject), try TypeNode().datum(of: try Subtree(type, as: "a cast's type").text())])
    }

    private func dictionary(_ held: Value) throws -> Datum {
        .node(
            "dictionary",
            try Subtree(held, as: "a map literal").list().map { entry in
                let pair = try Subtree(entry, as: "a map literal's entry").list()

                guard pair.count == 2 else {
                    throw TextRefused("a map literal's entry is a key and a value, and this one holds \(pair.count)")
                }

                return .node("entry", [try datum(of: pair[0]), try datum(of: pair[1])])
            }
        )
    }

    private func `struct`(_ held: Value) throws -> Datum {
        .node(
            "struct",
            try Subtree(held, as: "a struct literal").entries().map { name, value in
                .node("field", [.name(name), try datum(of: value)])
            }
        )
    }

    private func tagged(_ tag: ExpressionTag, _ held: Value) -> Value {
        .dictionary([tag.key: held])
    }

    private func call(_ callee: Value, handing arguments: ArraySlice<Datum>) throws -> Value {
        var written: [Name: Value] = [CallForm.CodingKeys.procedure.name: callee]

        if !arguments.isEmpty {
            written[CallForm.CodingKeys.arguments.name] = .array(try arguments.map(value(of:)))
        }

        return .dictionary(written)
    }
}
