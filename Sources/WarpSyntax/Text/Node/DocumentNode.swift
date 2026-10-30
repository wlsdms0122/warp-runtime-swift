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
//   (warp 1)                           warp: 1
//   (import Standard.Numeric.plus)     imports += "Standard.Numeric.plus"
//   (import App.Point Hashable)        imports += "App.Point: Hashable"
//   (const seven e)                    const: { seven: e }
//   (var count e)                      var: { count: e }
//   (var count (type Int) e)           var: { count: { type: "Int", value: e } }
//   (type App.Id Int)                  types: { "App.Id": "Int" }
//   (struct App.Box …)                 types: { "App.Box": { struct: { … }, … } }
//   (contract App.Named …)             contracts: { "App.Named": { … } }
//   (extension (head T) …)             extensions: { "T": { … } }
//   (procedure App.g …)                procedures: { "App.g": { … } }
//
// An interface is written in the same nodes, `(interface 1)` in the place of
// `(warp 1)`. It declares what another document may name, so it holds no
// `const` and no `var`, and each procedure, a member included, as its
// signature, with no `body` and no `access`.
struct DocumentNode {
    // What the nodes write: a document or an interface.
    enum Kind {
        case document
        case interface

        // The key the tree holds the language version under, which is the
        // word its text begins with.
        var version: Name {
            switch self {
            case .document: Module.versionKey
            case .interface: Loader.interfaceKey
            }
        }
    }

    // MARK: - Property
    private static let imports = ModuleReader.CodingKeys.imports.name.spelling
    private static let constants = ModuleReader.CodingKeys.const.name.spelling
    private static let variables = ModuleReader.CodingKeys.variables.name.spelling
    private static let types = ModuleReader.CodingKeys.types.name.spelling
    private static let contracts = ModuleReader.CodingKeys.contracts.name.spelling
    private static let extensions = ModuleReader.CodingKeys.extensions.name.spelling
    private static let procedures = ModuleReader.CodingKeys.procedures.name.spelling
    private static let access = ProcedureReader.CodingKeys.access.name.spelling
    private static let body = ProcedureReader.CodingKeys.body.name.spelling

    private static let type = VariableReader.typeKey.spelling
    private static let value = VariableReader.valueKey.spelling

    private let kind: Kind

    // MARK: - Initializer
    init(_ kind: Kind = .document) {
        self.kind = kind
    }

    // MARK: - Public
    // A document `depth` containers in: what its dictionaries hold stands two
    // further in, the document's own and the dictionary's.
    func value(of nodes: ArraySlice<Datum>, within depth: Int) throws -> Value {
        let inDictionary = depth + 2
        var keyed = Keyed()

        keyed.hold(Self.imports)

        for datum in nodes {
            let node = try Node(datum)

            if kind == .interface {
                try signature(of: node)
            }

            switch node.word {
            case kind.version.spelling:
                try keyed.write(try DataNode().value(of: node.one(), within: depth + 1), under: node.word, at: node.offset)

            case "import":
                keyed.append(.string(try DeclarationNode().introduced(node)), under: Self.imports)

            case Self.constants where kind == .document:
                let (name, held) = try node.named()

                try keyed.write(try ExpressionNode().value(of: held, within: inDictionary), named: name, under: node.word, at: node.offset)

            case Self.variables where kind == .document:
                try keyed.write(try variable(node, within: inDictionary), named: try node.declared().name, under: node.word, at: node.offset)

            case "type":
                let (name, type) = try node.named()

                try keyed.write(.string(try TypeNode().text(of: type)), named: name, under: Self.types, at: node.offset)

            case "struct":
                let (name, parts) = try node.declared()

                try keyed.write(try DeclarationNode().struct(parts, within: inDictionary), named: name, under: Self.types, at: node.offset)

            case "contract":
                let (name, parts) = try node.declared()

                try keyed.write(try DeclarationNode().contract(parts, within: inDictionary), named: name, under: Self.contracts, at: node.offset)

            case "extension":
                let (head, given) = try DeclarationNode().extension(node.operands[...], within: inDictionary, at: node.offset)

                try keyed.write(given, named: head, under: Self.extensions, at: node.offset)

            case "procedure":
                let (name, parts) = try node.declared()

                try keyed.write(try ProcedureNode().value(of: parts, within: inDictionary, at: node.offset), named: name, under: Self.procedures, at: node.offset)

            default:
                throw TextRefused("\(kind == .document ? "a document" : "an interface") holds no `(\(node.word) …)`", at: node.offset)
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

        if let version = fields.take(kind.version.spelling) {
            nodes.append(.node(kind.version.spelling, [try DataNode().datum(of: version)]))
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
    // A procedure of an interface's declaration, a member or a contract's
    // included, is its signature's parts alone.
    private func signature(of node: Node) throws {
        let parts = node.word == "procedure" ? [node] : node.operands.compactMap { operand in try? Node(operand) }

        for procedure in parts where procedure.word == "procedure" {
            for case let part? in procedure.operands.map({ operand in try? Node(operand) })
            where part.word == Self.body || part.word == Self.access {
                throw TextRefused("an interface's procedure holds no `\(part.word)`: it is its signature", at: part.offset)
            }
        }
    }

    // A variable's start, under the type it declares where it writes one.
    private func variable(_ node: Node, within depth: Int) throws -> Value {
        let (_, parts) = try node.declared()

        switch parts.count {
        case 1:
            return try ExpressionNode().value(of: parts[parts.startIndex], within: depth)

        case 2:
            guard parts.first?.word == Self.type else { break }

            return .dictionary([
                VariableReader.typeKey: .string(try TypeNode().text(of: Node(parts[parts.startIndex]).one())),
                VariableReader.valueKey: try ExpressionNode().value(of: parts[parts.startIndex + 1], within: depth + 1)
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
                .node(Self.type, [try TypeNode().datum(of: try Subtree(type, as: "a variable's type").string())]),
                try ExpressionNode().datum(of: value)
            ]
        )
    }
}
