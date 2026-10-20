//
//  DeclarationNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// What a struct, a contract and an extension hold, and the mappings they
// write. A name introduced beside its bounds is one text in the tree, cut at
// its `:` and its `&`, so a name holding either has no node there.
//
//   (struct App.Box
//     (typeParameter K App.Named Hashable)     typeParameters += "K: App.Named & Hashable"
//     (satisfies App.Named)                    satisfies ["App.Named"]
//     (field balance (var Int))                struct { balance "var Int" }
//     (type Item K)                            types { Item "K" }
//     (procedure area …))                      procedures { area { … } }
//   (contract App.Named
//     (type Item Hashable)                     types += "Item: Hashable"
//     (procedure name …))                      procedures { name { … } }
//   (extension (head (array Int)) …)           extensions { "Array<Int>" { … } }
struct DeclarationNode {
    // MARK: - Property
    private static let structKey = TypeDeclarationReader.structKey.spelling
    private static let typeParameters = TypeDeclarationReader.typeParametersKey.spelling
    private static let satisfies = ExtensionReader.CodingKeys.satisfies.name.spelling
    private static let types = ExtensionReader.CodingKeys.types.name.spelling
    private static let procedures = ExtensionReader.CodingKeys.procedures.name.spelling

    // MARK: - Initializer
    // MARK: - Public
    func `struct`(_ parts: ArraySlice<Datum>) throws -> Value {
        var keyed = Keyed()

        keyed.holdMap(Self.structKey)

        for operand in parts {
            let part = try Node(operand)

            switch part.word {
            case "typeParameter":
                keyed.append(.string(try introduced(part)), under: Self.typeParameters)

            case "field":
                let (name, type) = try part.named()

                try keyed.write(.string(try TypeNode().text(of: type)), named: name, under: Self.structKey, at: part.offset)

            default:
                try given(part, into: &keyed)
            }
        }

        return try keyed.value()
    }

    func `struct`(of value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "a struct's declaration")

        guard let declared = fields.take(Self.structKey) else {
            throw Unplaced("a struct's declaration writes `struct`, and no node writes one without it")
        }

        var parts: [Datum] = []

        if let introduced = fields.take(Self.typeParameters) {
            parts += try self.introduced(introduced, as: "typeParameter")
        }

        let given = try self.given(&fields, as: "a struct's declaration")

        parts += given.satisfies
        parts += try Fields.entries(declared, as: "a struct's fields").map { name, type in
            .node("field", [.name(name), try TypeNode().datum(of: try Fields.text(type, as: "a field's type"))])
        }
        parts += given.rest

        try fields.finish()

        return parts
    }

    func contract(_ parts: ArraySlice<Datum>) throws -> Value {
        var keyed = Keyed()

        for operand in parts {
            let part = try Node(operand)

            switch part.word {
            case "type":
                keyed.append(.string(try introduced(part)), under: ContractReader.CodingKeys.types.name.spelling)

            case "procedure":
                let (name, held) = try part.declared()

                try keyed.write(try ProcedureNode().value(of: held), named: name, under: Self.procedures, at: part.offset)

            default:
                throw Unplaced("a contract holds no `\(part.word)`", at: part.offset)
            }
        }

        return try keyed.value()
    }

    func contract(of value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "a contract")
        var parts: [Datum] = []

        if let asked = fields.take(ContractReader.CodingKeys.types.name.spelling) {
            parts += try introduced(asked, as: "type")
        }

        if let procedures = fields.take(Self.procedures) {
            parts += try self.procedures(procedures)
        }

        try fields.finish()

        return parts
    }

    // An extension's head, the text its key is, and what it gives the type.
    func `extension`(_ parts: ArraySlice<Datum>, at offset: Int?) throws -> (head: String, given: Value) {
        var keyed = Keyed()
        var head: String?

        for operand in parts {
            let part = try Node(operand)

            guard part.word == "head" else {
                try given(part, into: &keyed)

                continue
            }

            guard head == nil else {
                throw Unplaced("`head` is written twice", at: part.offset)
            }

            head = try TypeNode().text(of: part.one())
        }

        guard let head else {
            throw Unplaced("an extension writes its `head`, the type it extends", at: offset)
        }

        return (head, try keyed.value())
    }

    func `extension`(of head: String, _ value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "an extension")
        let given = try self.given(&fields, as: "an extension")

        try fields.finish()

        return [.node("head", [try TypeNode().datum(of: head)])] + given.satisfies + given.rest
    }

    // A name and the contracts bounding it, `K: A & B`, as `(word K A B)`.
    func introduced(_ node: Node) throws -> String {
        let (name, contracts) = try node.declared()
        let names = try [name] + contracts.map(Node.name)

        if let held = names.first(where: { name in name.rangeOfCharacter(from: TypeNode.cut) != nil }) {
            throw Unplaced("'\(held)' holds what the tree cuts a name from its bounds at", at: node.offset)
        }

        guard !contracts.isEmpty else { return name }

        return "\(name): \(names.dropFirst().joined(separator: " & "))"
    }

    func introduced(_ value: Value, as word: String) throws -> [Datum] {
        let list = try Fields.list(value, as: "a list of names")

        guard !list.isEmpty else {
            throw Unplaced("no node writes an empty list of `\(word)`")
        }

        return try list.map { element in
            let text = try Fields.text(element, as: "a name and its bounds")
            let parts = text.components(separatedBy: ": ")

            let names = parts.count == 2 ? [parts[0]] + parts[1].components(separatedBy: " & ") : parts
            let datum = Datum.node(word, names.map(Datum.name))

            guard (try? introduced(Node(datum))) == text else {
                throw Unplaced("'\(text)' cuts at its `:` into names no node writes back as itself")
            }

            return datum
        }
    }

    // MARK: - Private
    // What a struct's declaration and an extension both give a type: the
    // contracts it satisfies, its types and its members.
    private func given(_ part: Node, into keyed: inout Keyed) throws {
        switch part.word {
        case Self.satisfies:
            try keyed.write(.array(try part.operands.map { operand in .string(try Node.name(operand)) }), under: part.word, at: part.offset)

        case "type":
            let (name, type) = try part.named()

            try keyed.write(.string(try TypeNode().text(of: type)), named: name, under: Self.types, at: part.offset)

        case "procedure":
            let (name, held) = try part.declared()

            try keyed.write(try ProcedureNode().value(of: held), named: name, under: Self.procedures, at: part.offset)

        default:
            throw Unplaced("no declaration here holds `\(part.word)`", at: part.offset)
        }
    }

    private func given(_ fields: inout Fields, as place: String) throws -> (satisfies: [Datum], rest: [Datum]) {
        var satisfies: [Datum] = []
        var rest: [Datum] = []

        if let contracts = fields.take(Self.satisfies) {
            let names = try Fields.list(contracts, as: "what \(place) satisfies").map { contract in
                Datum.name(try Fields.text(contract, as: "a contract's name"))
            }

            satisfies.append(.node(Self.satisfies, names))
        }

        if let types = fields.take(Self.types) {
            rest += try Fields.entries(types, as: "the types \(place) gives").map { name, type in
                .node("type", [.name(name), try TypeNode().datum(of: try Fields.text(type, as: "a given type"))])
            }
        }

        if let procedures = fields.take(Self.procedures) {
            rest += try self.procedures(procedures)
        }

        return (satisfies, rest)
    }

    private func procedures(_ value: Value) throws -> [Datum] {
        try Fields.entries(value, as: "a mapping of procedures").map { name, procedure in
            .block("procedure", [.name(name)] + (try ProcedureNode().parts(of: procedure)))
        }
    }
}
