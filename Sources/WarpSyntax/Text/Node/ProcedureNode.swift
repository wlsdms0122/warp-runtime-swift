//
//  ProcedureNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A procedure's parts, as a declaration, a closure, a contract's procedure
// and a vocabulary's procedure each hold them, and the mapping they write.
//
//   (description "…")                  description "…"
//   (access public)                    access "public"
//   (const)  (isolated)                const true, isolated true
//   (parameter f (type T) (description "…"))
//                                      parameters += { name "f", type "T", description "…" }
//   (returns T)                        returns "T"
//   (failing a b)  (failing (anything))
//                                      failing ["a", "b"], failing "anything"
//   (bound C.Item A B)                 bounds { "C.Item" "A & B" }
//   (sameType C.Item T)                sameTypes { "C.Item" "T" }
//   (body …)  (result e)               body [ … ], result e
//   (answers v)                        answers v, read as data
struct ProcedureNode {
    // MARK: - Property
    private static let description = ProcedureReader.CodingKeys.description.name.spelling
    private static let access = ProcedureReader.CodingKeys.access.name.spelling
    private static let const = SignatureFieldsReader.CodingKeys.const.name.spelling
    private static let isolated = SignatureFieldsReader.CodingKeys.isolated.name.spelling
    private static let parameters = SignatureFieldsReader.CodingKeys.parameters.name.spelling
    private static let returns = SignatureFieldsReader.CodingKeys.returns.name.spelling
    private static let failing = SignatureFieldsReader.CodingKeys.failing.name.spelling
    private static let bounds = SignatureFieldsReader.CodingKeys.bounds.name.spelling
    private static let sameTypes = SignatureFieldsReader.CodingKeys.sameTypes.name.spelling
    private static let body = BlockReader.CodingKeys.body.name.spelling
    private static let result = BlockReader.CodingKeys.result.name.spelling
    private static let answers = "answers"

    private static let name = ParameterReader.CodingKeys.name.name.spelling
    private static let type = ParameterFieldsReader.CodingKeys.type.name.spelling

    // MARK: - Initializer
    // MARK: - Public
    func value(of parts: ArraySlice<Datum>) throws -> Value {
        var keyed = Keyed()

        for operand in parts {
            let part = try Node(operand)

            switch part.word {
            case Self.description, Self.answers:
                try keyed.write(try DataNode().value(of: part.one()), under: part.word, at: part.offset)

            case Self.access:
                try keyed.write(.string(try Node.name(part.one())), under: part.word, at: part.offset)

            case Self.const, Self.isolated:
                try part.none()
                try keyed.write(.bool(true), under: part.word, at: part.offset)

            case "parameter":
                keyed.append(try parameter(part), under: Self.parameters)

            case Self.returns:
                try keyed.write(.string(try TypeNode().text(of: part.one())), under: part.word, at: part.offset)

            case Self.failing:
                try keyed.write(try failing(part), under: part.word, at: part.offset)

            case "bound":
                let (label, contracts) = try part.declared()

                guard !contracts.isEmpty else {
                    throw TextRefused("`bound` holds an associated type and the contracts it is bounded by", at: part.offset)
                }

                let names = try contracts.map(Node.name)
                let joined = names.joined(separator: " & ")

                guard TypeParser().names(joined) == names else {
                    throw TextRefused("'\(joined)' is read as other contracts than these, so they have no text", at: part.offset)
                }

                try keyed.write(.string(joined), named: label, under: Self.bounds, at: part.offset)

            case "sameType":
                let (label, type) = try part.named()

                try keyed.write(.string(try TypeNode().text(of: type)), named: label, under: Self.sameTypes, at: part.offset)

            case Self.body:
                try keyed.write(try StatementNode().value(of: part.operands[...]), under: part.word, at: part.offset)

            case Self.result:
                try keyed.write(try ExpressionNode().value(of: part.one()), under: part.word, at: part.offset)

            default:
                throw TextRefused("a procedure holds no `\(part.word)`", at: part.offset)
            }
        }

        return try keyed.value()
    }

    func parts(of value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "a procedure")
        var parts: [Datum] = []

        if let description = fields.take(Self.description) {
            parts.append(.node(Self.description, [try DataNode().datum(of: description)]))
        }

        if let access = fields.take(Self.access) {
            parts.append(.node(Self.access, [.name(try Fields.text(access, as: "an access"))]))
        }

        for mark in [Self.const, Self.isolated] {
            guard let held = fields.take(mark) else { continue }

            guard held == .bool(true) else {
                throw TextRefused("`\(mark)` is written `true` or not at all, and no node writes \(Rendering(held).text())")
            }

            parts.append(.node(mark))
        }

        if let parameters = fields.take(Self.parameters) {
            let list = try Fields.list(parameters, as: "a procedure's parameters")

            guard !list.isEmpty else {
                throw TextRefused("a procedure writes `parameters` where it takes some, and no node writes it empty")
            }

            parts += try list.map(parameter)
        }

        if let returns = fields.take(Self.returns) {
            parts.append(.node(Self.returns, [try TypeNode().datum(of: try Fields.text(returns, as: "what a procedure returns"))]))
        }

        if let failing = fields.take(Self.failing) {
            parts.append(try self.failing(failing))
        }

        if let bounds = fields.take(Self.bounds) {
            parts += try Fields.entries(bounds, as: "a procedure's bounds").map { label, contracts in
                let written = try Fields.text(contracts, as: "a bound")
                let names = TypeParser().names(written)

                guard names.joined(separator: " & ") == written else {
                    throw TextRefused("the bound '\(written)' is spelled as no node writes it")
                }

                return .node("bound", [.name(label)] + names.map(Datum.name))
            }
        }

        if let sameTypes = fields.take(Self.sameTypes) {
            parts += try Fields.entries(sameTypes, as: "a procedure's same types").map { label, type in
                .node("sameType", [.name(label), try TypeNode().datum(of: try Fields.text(type, as: "a same type"))])
            }
        }

        if let body = fields.take(Self.body) {
            parts.append(.block(Self.body, try StatementNode().data(of: body, as: "a procedure's body")))
        }

        if let result = fields.take(Self.result) {
            parts.append(.node(Self.result, [try ExpressionNode().datum(of: result)]))
        }

        if let answers = fields.take(Self.answers) {
            parts.append(.node(Self.answers, [try DataNode().datum(of: answers)]))
        }

        try fields.finish()

        return parts
    }

    // MARK: - Private
    private func parameter(_ node: Node) throws -> Value {
        let (name, parts) = try node.declared()
        var keyed = Keyed()

        try keyed.write(.string(name), under: Self.name, at: node.offset)

        for operand in parts {
            let part = try Node(operand)

            switch part.word {
            case Self.type:
                try keyed.write(.string(try TypeNode().text(of: part.one())), under: part.word, at: part.offset)

            case Self.description:
                try keyed.write(try DataNode().value(of: part.one()), under: part.word, at: part.offset)

            default:
                throw TextRefused("a parameter holds no `\(part.word)`", at: part.offset)
            }
        }

        return try keyed.value()
    }

    private func parameter(_ value: Value) throws -> Datum {
        var fields = try Fields(value, as: "a parameter")

        guard let name = fields.take(Self.name) else {
            throw TextRefused("a parameter writes its name, and no node writes one without it")
        }

        var parts: [Datum] = [.name(try Fields.text(name, as: "a parameter's name"))]

        if let type = fields.take(Self.type) {
            parts.append(.node(Self.type, [try TypeNode().datum(of: try Fields.text(type, as: "a parameter's type"))]))
        }

        if let description = fields.take(Self.description) {
            parts.append(.node(Self.description, [try DataNode().datum(of: description)]))
        }

        try fields.finish()

        return .node("parameter", parts)
    }

    // What a body may fail with: names, or anything, which is a node since
    // a name could be called `anything`.
    private func failing(_ node: Node) throws -> Value {
        if node.operands.count == 1, node.operands[0].word == Failing.anythingSpelling {
            try Node(node.operands[0]).none()

            return .string(Failing.anythingSpelling)
        }

        return .array(try node.operands.map { operand in .string(try Node.name(operand)) })
    }

    private func failing(_ value: Value) throws -> Datum {
        switch value {
        case .string(Failing.anythingSpelling):
            return .node(Self.failing, [.node(Failing.anythingSpelling)])

        case let .array(failures):
            return .node(Self.failing, try failures.map { failure in .name(try Fields.text(failure, as: "a failure")) })

        default:
            throw TextRefused("a procedure fails with a list of names or with `anything`, and no node writes \(Rendering(value).text())")
        }
    }
}
