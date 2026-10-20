//
//  DocumentNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A document as the nodes it is, and its tree. `imports` is written whether
// or not any node imports, so a tree with no `imports` has no nodes.
//
//   (warp 1)                           warp 1
//   (description "…")                  description "…"
//   (import Standard.Numeric.plus)     imports += "Standard.Numeric.plus"
//   (import App.Point Hashable)        imports += "App.Point: Hashable"
//   (const seven e)                    const { seven e }
//   (var count e)                      var { count e }
//   (var count (type Int) e)           var { count { type "Int", value e } }
//   (type App.Id Int)                  types { "App.Id" "Int" }
//   (struct App.Box …)                 types { "App.Box" { struct { … }, … } }
//   (contract App.Named …)             contracts { "App.Named" { … } }
//   (extension (head T) …)             extensions { "T" { … } }
//   (procedure App.g …)                procedures { "App.g" { … } }
struct DocumentNode {
    // MARK: - Property
    private static let warp = Module.versionKey.spelling
    private static let description = ModuleReader.CodingKeys.description.name.spelling
    private static let imports = ModuleReader.CodingKeys.imports.name.spelling
    private static let constants = ModuleReader.CodingKeys.const.name.spelling
    private static let variables = ModuleReader.CodingKeys.variables.name.spelling
    private static let types = ModuleReader.CodingKeys.types.name.spelling
    private static let contracts = ModuleReader.CodingKeys.contracts.name.spelling
    private static let extensions = ModuleReader.CodingKeys.extensions.name.spelling
    private static let procedures = ModuleReader.CodingKeys.procedures.name.spelling

    private static let type = VariableReader.typeKey.spelling
    private static let value = VariableReader.valueKey.spelling

    // MARK: - Initializer
    // MARK: - Public
    func value(of nodes: ArraySlice<Datum>) throws -> Value {
        var keyed = Keyed()

        keyed.hold(Self.imports)

        for datum in nodes {
            let node = try Node(datum)

            switch node.word {
            case Self.warp, Self.description:
                try keyed.write(try DataNode().value(of: node.one()), under: node.word, at: node.offset)

            case "import":
                keyed.append(.string(try DeclarationNode().introduced(node)), under: Self.imports)

            case Self.constants:
                let (name, held) = try node.named()

                try keyed.write(try ExpressionNode().value(of: held), named: name, under: node.word, at: node.offset)

            case Self.variables:
                try keyed.write(try variable(node), named: try node.declared().name, under: node.word, at: node.offset)

            case "type":
                let (name, type) = try node.named()

                try keyed.write(.string(try TypeNode().text(of: type)), named: name, under: Self.types, at: node.offset)

            case "struct":
                let (name, parts) = try node.declared()

                try keyed.write(try DeclarationNode().struct(parts), named: name, under: Self.types, at: node.offset)

            case "contract":
                let (name, parts) = try node.declared()

                try keyed.write(try DeclarationNode().contract(parts), named: name, under: Self.contracts, at: node.offset)

            case "extension":
                let (head, given) = try DeclarationNode().extension(node.operands[...], at: node.offset)

                try keyed.write(given, named: head, under: Self.extensions, at: node.offset)

            case "procedure":
                let (name, parts) = try node.declared()

                try keyed.write(try ProcedureNode().value(of: parts), named: name, under: Self.procedures, at: node.offset)

            default:
                throw TextRefused("a document holds no `(\(node.word) …)`", at: node.offset)
            }
        }

        return try keyed.value()
    }

    func nodes(of value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "a document")
        var nodes: [Datum] = []

        guard let imports = fields.take(Self.imports) else {
            throw TextRefused("a document writes `imports`, and no node writes one without it")
        }

        if let version = fields.take(Self.warp) {
            nodes.append(.node(Self.warp, [try DataNode().datum(of: version)]))
        }

        if let description = fields.take(Self.description) {
            nodes.append(.node(Self.description, [try DataNode().datum(of: description)]))
        }

        if !(try Subtree(imports, as: "a document's imports").list()).isEmpty {
            nodes += try DeclarationNode().introduced(imports, as: "import")
        }

        if let constants = fields.take(Self.constants) {
            nodes += try Subtree(constants, as: "a document's constants").entries().map { name, held in
                .node(Self.constants, [.name(name), try ExpressionNode().datum(of: held)])
            }
        }

        if let variables = fields.take(Self.variables) {
            nodes += try Subtree(variables, as: "a document's variables").entries().map(variable)
        }

        if let types = fields.take(Self.types) {
            nodes += try Subtree(types, as: "a document's types").entries().map { name, declared in
                guard case let .string(type) = declared else {
                    return .block("struct", [.name(name)] + (try DeclarationNode().struct(of: declared)))
                }

                return .node("type", [.name(name), try TypeNode().datum(of: type)])
            }
        }

        if let contracts = fields.take(Self.contracts) {
            nodes += try Subtree(contracts, as: "a document's contracts").entries().map { name, contract in
                .block("contract", [.name(name)] + (try DeclarationNode().contract(of: contract)))
            }
        }

        if let extensions = fields.take(Self.extensions) {
            nodes += try Subtree(extensions, as: "a document's extensions").entries().map { head, given in
                .block("extension", try DeclarationNode().extension(of: head, given))
            }
        }

        if let procedures = fields.take(Self.procedures) {
            nodes += try Subtree(procedures, as: "a document's procedures").entries().map { name, procedure in
                .block("procedure", [.name(name)] + (try ProcedureNode().parts(of: procedure)))
            }
        }

        try fields.finish()

        return nodes
    }

    // MARK: - Private
    // A variable's start, under the type it declares where it writes one.
    private func variable(_ node: Node) throws -> Value {
        let (_, parts) = try node.declared()

        switch parts.count {
        case 1:
            return try ExpressionNode().value(of: parts[parts.startIndex])

        case 2:
            guard parts.first?.word == Self.type else { break }

            return .dictionary([
                VariableReader.typeKey: .string(try TypeNode().text(of: Node(parts[parts.startIndex]).one())),
                VariableReader.valueKey: try ExpressionNode().value(of: parts[parts.startIndex + 1])
            ])

        default:
            break
        }

        throw TextRefused("a document's `var` holds a name, a type where it declares one, and its start", at: node.offset)
    }

    private func variable(_ name: String, _ start: Value) throws -> Datum {
        guard
            case let .dictionary(held) = start,
            held.count == 2,
            let type = held[VariableReader.typeKey],
            let value = held[VariableReader.valueKey]
        else {
            return .node(Self.variables, [.name(name), try ExpressionNode().datum(of: start)])
        }

        return .node(
            Self.variables,
            [
                .name(name),
                .node(Self.type, [try TypeNode().datum(of: try Subtree(type, as: "a variable's type").text())]),
                try ExpressionNode().datum(of: value)
            ]
        )
    }
}
