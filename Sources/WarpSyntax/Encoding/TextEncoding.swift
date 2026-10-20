//
//  TextEncoding.swift
//  WarpSyntax
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The text a document and a conformance case are written in: the IR's own
// spelling, in two layers. The first reads atoms and lists and knows nothing
// of what a tree holds (`DatumReader`). The second reads a list by the word it
// begins with and makes the tree's node (`DocumentNode`, `CaseNode`), judging
// nothing: what a tree says is the loader's to read.
//
// One tree, one text. The writer lays a text out one way, so a text that has
// been through it is the same bytes everywhere, and refuses a tree no node
// writes back as itself. Layout is free on the way in, white space and the
// order of a mapping's keys; the spelling of a value is not.
public struct TextEncoding {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func text(from value: Value) throws -> String {
        guard value.nesting <= Value.nestingBound else {
            throw EncodingRefused("the tree nests deeper than a document may")
        }

        let text = try refusing(in: []) {
            let isCase = (try? Fields.entries(value, as: "a tree"))?.contains { key, _ in key == CaseNode.test } == true
            let nodes = isCase ? try CaseNode().nodes(of: value) : try DocumentNode().nodes(of: value)

            guard let first = nodes.first?.word, first == (isCase ? CaseNode.test : Module.versionKey.spelling) else {
                throw Unplaced(
                    "a text begins with what it is, `(\(Module.versionKey) …)` or `(\(CaseNode.test) …)`, and this tree writes neither"
                )
            }

            return try DatumWriter().text(of: nodes)
        }

        guard (try? self.value(from: text)) == value else {
            throw EncodingRefused("no node writes this tree: its text reads back as another")
        }

        return text
    }

    // The same value as data on one line, for a sentence that quotes it.
    func line(from value: Value) throws -> String {
        try refusing(in: []) {
            try DatumWriter().line(of: DataNode().datum(of: value))
        }
    }

    public func data(from value: Value) throws -> Data {
        Data(try text(from: value).utf8)
    }

    public func value(from data: Data) throws -> Value {
        guard let text = String(utf8: data) else {
            throw EncodingRefused("the text is not UTF-8")
        }

        return try value(from: text)
    }

    public func value(from text: String) throws -> Value {
        let scalars = Array(text.unicodeScalars)
        let value = try refusing(in: scalars) { try read(scalars) }

        guard value.nesting <= Value.nestingBound else {
            throw EncodingRefused("the document nests deeper than a reader must follow")
        }

        return value
    }

    // MARK: - Private
    // What the text is, a document or a case, is the word it begins with,
    // read before anything after it.
    private func read(_ scalars: [Unicode.Scalar]) throws -> Value {
        let nodes = try DatumReader().data(of: scalars)

        switch nodes.first?.word {
        case Module.versionKey.spelling:
            return try DocumentNode().value(of: nodes[...])

        case CaseNode.test:
            return try CaseNode().value(of: nodes)

        default:
            throw Unplaced(
                "a text begins with what it is, `(\(Module.versionKey) …)` or `(\(CaseNode.test) …)`",
                at: nodes.first?.offset ?? 0
            )
        }
    }

    // The door the text's layers refuse through: what they refuse said once,
    // with the line and column the offset stands at, both counted from one,
    // the column in scalars. A refusal of what is being written stands at
    // no line.
    private func refusing<Made>(in scalars: [Unicode.Scalar], _ making: () throws -> Made) throws -> Made {
        do {
            return try making()
        } catch let unplaced as Unplaced {
            guard let offset = unplaced.offset else { throw EncodingRefused(unplaced.said) }

            var line = 1
            var column = 1

            for (index, scalar) in scalars.prefix(offset).enumerated() {
                if scalar == "\n" || scalar == "\r" && (index + 1 < scalars.count ? scalars[index + 1] : nil) != "\n" {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
            }

            throw EncodingRefused(unplaced.said, at: EncodingRefused.Position(line: line, column: column))
        }
    }
}
