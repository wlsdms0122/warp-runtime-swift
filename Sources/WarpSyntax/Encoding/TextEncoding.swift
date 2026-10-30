//
//  TextEncoding.swift
//  WarpSyntax
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The text a document, an interface and a conformance case are written in:
// the IR's own spelling, in two layers. The first reads atoms and lists and
// knows nothing of what a tree holds (`DatumReader`). The second reads a list
// by the word it begins with and makes the tree's node (`DocumentNode`,
// `CaseNode`), counting the containers it opens against the bound every
// reader holds and judging nothing else: what a tree says is the loader's to
// read.
//
// One tree, one text. The writer lays a text out one way, so a text that has
// been through it is the same bytes everywhere, and refuses a tree no node
// writes back as itself. Layout is free on the way in, white space and the
// order of a mapping's keys; the spelling of a value is not.
public struct TextEncoding {
    // MARK: - Property
    private static let kinds = [Module.versionKey.spelling, Loader.interfaceKey.spelling, CaseNode.test]
    private static let beginning = "a text begins with what it is, `(\(Module.versionKey) …)`, `(\(Loader.interfaceKey) …)` or `(\(CaseNode.test) …)`"

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func text(from value: Value) throws -> String {
        guard value.nesting <= Value.nestingBound else {
            throw EncodingRefused("the tree nests deeper than a document may")
        }

        let text = try refusing(in: []) {
            let nodes = try nodes(of: value)

            guard let first = nodes.first?.word, Self.kinds.contains(first) else {
                throw TextRefused("\(Self.beginning), and this tree writes none of them")
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

        return try refusing(in: scalars) { try read(scalars) }
    }

    // MARK: - Private
    // What the text is, a document, an interface or a case, is the word it
    // begins with, read before anything after it.
    private func read(_ scalars: [Unicode.Scalar]) throws -> Value {
        let nodes = try DatumReader().data(of: scalars)

        switch nodes.first?.word {
        case Module.versionKey.spelling:
            return try DocumentNode().value(of: nodes[...], within: 0)

        case Loader.interfaceKey.spelling:
            return try DocumentNode(.interface).value(of: nodes[...], within: 0)

        case CaseNode.test:
            return try CaseNode().value(of: nodes)

        default:
            throw TextRefused(Self.beginning, at: nodes.first?.offset ?? 0)
        }
    }

    // A tree is what it holds its first word under.
    private func nodes(of value: Value) throws -> [Datum] {
        let keys = (try? Subtree(value, as: "a tree").entries())?.map(\.key) ?? []

        if keys.contains(CaseNode.test) {
            return try CaseNode().nodes(of: value)
        }

        if keys.contains(Loader.interfaceKey.spelling) {
            return try DocumentNode(.interface).nodes(of: value)
        }

        return try DocumentNode().nodes(of: value)
    }

    // The door the text's layers refuse through: what they refuse said once,
    // with the line and column the offset stands at, both counted from one,
    // the column in scalars. A refusal of what is being written stands at
    // no line.
    private func refusing<Made>(in scalars: [Unicode.Scalar], _ making: () throws -> Made) throws -> Made {
        do {
            return try making()
        } catch let refusal as TextRefused {
            guard let offset = refusal.offset else { throw EncodingRefused(refusal.said) }

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

            throw EncodingRefused(refusal.said, at: EncodingRefused.Position(line: line, column: column))
        }
    }
}
