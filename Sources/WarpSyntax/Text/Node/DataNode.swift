//
//  DataNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A value as data: a scalar as its atom, and a container as the node that
// holds what it holds. A map is keyed by values, and a struct is named.
//
//   null true 1 1.5 "a" x"6a"
//   (array 1 2)
//   (dictionary (entry "a" 1) (entry 2 x"00"))
//   (struct App.Point (field x 1) (field y 2))
struct DataNode {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func value(of datum: Datum) throws -> Value {
        switch datum.form {
        case .null:
            return .null

        case let .bool(bool):
            return .bool(bool)

        case let .int(int):
            return .int(int)

        case let .double(double):
            return .double(double)

        case let .text(text):
            return .string(text)

        case let .bytes(bytes):
            return .bytes(bytes)

        case let .name(name):
            throw Unplaced("'\(name)' is a name, and data holds values", at: datum.offset)

        case .list:
            let node = try Node(datum)

            switch node.word {
            case "array": return .array(try node.operands.map(value(of:)))
            case "dictionary": return try dictionary(node)
            case "struct": return try `struct`(node)
            default: throw Unplaced("data holds no `(\(node.word) …)`", at: node.offset)
            }
        }
    }

    func datum(of value: Value) throws -> Datum {
        switch value {
        case .null:
            return Datum(.null)

        case let .bool(bool):
            return Datum(.bool(bool))

        case let .int(int):
            return Datum(.int(int))

        case let .double(double):
            guard double.isFinite else {
                throw EncodingRefused("only a finite fraction has a spelling, and \(double) is none")
            }

            return Datum(.double(double))

        case let .string(text):
            return Datum(.text(text))

        case let .bytes(bytes):
            return Datum(.bytes(bytes))

        case let .array(elements):
            return .node("array", try elements.map(datum(of:)))

        case let .dictionary(held):
            return try dictionary(held)

        case let .struct(instance):
            return try `struct`(instance)

        case .procedure:
            throw EncodingRefused("a procedure closed over a scope is not data, and a text holds data")
        }
    }

    // MARK: - Private
    private func dictionary(_ node: Node) throws -> Value {
        let entries = try node.operands.map { operand in
            let entry = try Node(operand)

            guard entry.word == "entry", entry.operands.count == 2 else {
                throw Unplaced("a map holds `(entry key value)`", at: operand.offset)
            }

            return (key: try value(of: entry.operands[0]), value: try value(of: entry.operands[1]))
        }

        do {
            return .dictionary(try Value.Dictionary(entries))
        } catch let refusal as ValueRefused {
            throw Unplaced(refusal.message, at: node.offset)
        }
    }

    private func `struct`(_ node: Node) throws -> Value {
        let (name, parts) = try node.declared()

        let fields = try parts.map { operand in
            let field = try Node(operand)

            guard field.word == "field" else {
                throw Unplaced("a struct holds `(field name value)`", at: operand.offset)
            }

            let (named, held) = try field.named()

            return (name: try self.name(named, at: field.offset), value: try value(of: held))
        }

        do {
            return try .holding(fields, named: try self.name(name, at: node.offset))
        } catch let refusal as ValueRefused {
            throw Unplaced(refusal.message, at: node.offset)
        }
    }

    private func dictionary(_ held: Value.Dictionary) throws -> Datum {
        .node(
            "dictionary",
            try held.entries.map { entry in .node("entry", [try datum(of: entry.key), try datum(of: entry.value)]) }
        )
    }

    private func `struct`(_ instance: Struct) throws -> Datum {
        .node(
            "struct",
            [.name(instance.name.spelling)] + (try zip(instance.layout.fields, instance.values).map { name, value in
                .node("field", [.name(name.spelling), try datum(of: value)])
            })
        )
    }

    private func name(_ spelling: String, at offset: Int?) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw Unplaced(refusal.message, at: offset)
        }
    }
}
