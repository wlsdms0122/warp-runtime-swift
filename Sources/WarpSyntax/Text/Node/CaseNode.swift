//
//  CaseNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A conformance case as the nodes it is, and its tree. What a case holds is
// data, its program and the documents beside it are documents, and a program
// no node writes is carried as its tree, as data.
//
//   (test 1)                           test: 1
//   (name "…")  (note "…")             name: "…", note: "…"
//   (program (warp 1) …)               program: { … }
//   (tree <value>)                     program: <value>, where no node writes it
//   (documents (document (warp 1) …))  documents: [{ … }]
//   (vocabulary (import …) …)          vocabulary: { … }
//   (arguments (argument c false))     arguments: { c: false }
//   (bytes x"…")  (text "…")  (object <value>)  (document x"…")
//   (expect (answers <value>))         expect: { answers: <value> }
//   (expect (refuses load))            expect: { refuses: "load" }
struct CaseNode {
    // MARK: - Property
    static let test = "test"

    private static let program = "program"
    private static let tree = "tree"
    private static let documents = "documents"
    private static let vocabulary = "vocabulary"
    private static let arguments = "arguments"
    private static let expect = "expect"
    private static let refuses = "refuses"

    // What a case holds as data, in the order it is written: what it is,
    // then what it asks about, then what it expects.
    private static let data = [test, "name", "note"]
    private static let subjects = ["bytes", "text", "object", "document"]
    private static let expectations = ["answers", "reads", "spells", "builds", refuses]

    // MARK: - Initializer
    // MARK: - Public
    // A case is a tree's first container, so what it holds stands one in.
    func value(of nodes: [Datum]) throws -> Value {
        var keyed = Keyed()

        for datum in nodes {
            let node = try Node(datum)

            switch node.word {
            case _ where (Self.data + Self.subjects).contains(node.word):
                try keyed.write(try DataNode().value(of: node.one(), within: 1), under: node.word, at: node.offset)

            case Self.program:
                try keyed.write(try DocumentNode().value(of: node.operands[...], within: 1), under: node.word, at: node.offset)

            case Self.tree:
                let tree = try DataNode().value(of: node.one(), within: 1)

                if written(tree) != nil {
                    throw TextRefused("a tree a node writes is written as `(program …)`", at: node.offset)
                }

                try keyed.write(tree, under: Self.program, at: node.offset)

            case Self.documents:
                let documents = try node.operands.map { operand in
                    let document = try Node(operand)

                    guard document.word == "document" else {
                        throw TextRefused("`documents` holds `(document …)`", at: operand.offset)
                    }

                    return try DocumentNode().value(of: document.operands[...], within: 2)
                }

                try keyed.write(.array(documents), under: node.word, at: node.offset)

            case Self.vocabulary:
                try keyed.write(try DocumentNode().value(of: node.operands[...], within: 1), under: node.word, at: node.offset)

            case Self.arguments:
                var arguments = Keyed()

                for operand in node.operands {
                    let argument = try Node(operand)

                    guard argument.word == "argument" else {
                        throw TextRefused("`arguments` holds `(argument name value)`", at: operand.offset)
                    }

                    let (name, held) = try argument.named()

                    try arguments.write(try DataNode().value(of: held, within: 2), under: name, at: argument.offset)
                }

                try keyed.write(try arguments.value(), under: node.word, at: node.offset)

            case Self.expect:
                var expected = Keyed()

                for operand in node.operands {
                    let expectation = try Node(operand)

                    guard Self.expectations.contains(expectation.word) else {
                        throw TextRefused("a case expects no `\(expectation.word)`", at: expectation.offset)
                    }

                    let held = expectation.word == Self.refuses
                        ? Value.string(try Node.name(expectation.one()))
                        : try DataNode().value(of: expectation.one(), within: 2)

                    try expected.write(held, under: expectation.word, at: expectation.offset)
                }

                try keyed.write(try expected.value(), under: node.word, at: node.offset)

            default:
                throw TextRefused("a case holds no `(\(node.word) …)`", at: node.offset)
            }
        }

        return try keyed.value()
    }

    func nodes(of value: Value) throws -> [Datum] {
        var fields = try Fields(value, as: "a case")
        var nodes: [Datum] = []

        for key in Self.data {
            if let held = fields.take(key) {
                nodes.append(.node(key, [try DataNode().datum(of: held)]))
            }
        }

        if let documents = fields.take(Self.documents) {
            nodes.append(
                .block(
                    Self.documents,
                    try Subtree(documents, as: "the documents beside a case's program").list().map { document in
                        .block("document", try DocumentNode().nodes(of: document))
                    }
                )
            )
        }

        if let vocabulary = fields.take(Self.vocabulary) {
            nodes.append(.block(Self.vocabulary, try DocumentNode().nodes(of: vocabulary)))
        }

        if let program = fields.take(Self.program) {
            if let parts = written(program) {
                nodes.append(.block(Self.program, parts))
            } else {
                nodes.append(.node(Self.tree, [try DataNode().datum(of: program)]))
            }
        }

        for key in Self.subjects {
            if let held = fields.take(key) {
                nodes.append(.node(key, [try DataNode().datum(of: held)]))
            }
        }

        if let arguments = fields.take(Self.arguments) {
            nodes.append(
                .node(
                    Self.arguments,
                    try Subtree(arguments, as: "a case's arguments").entries().map { name, held in
                        .node("argument", [.name(name), try DataNode().datum(of: held)])
                    }
                )
            )
        }

        if let expect = fields.take(Self.expect) {
            var expected = try Fields(expect, as: "what a case expects")
            var expectations: [Datum] = []

            for key in Self.expectations {
                guard let held = expected.take(key) else { continue }

                let written = key == Self.refuses
                    ? Datum.name(try Subtree(held, as: "where a case is refused").string())
                    : try DataNode().datum(of: held)

                expectations.append(.node(key, [written]))
            }

            try expected.finish()

            nodes.append(.node(Self.expect, expectations))
        }

        try fields.finish()

        return nodes
    }

    // MARK: - Private
    // A program's nodes, where they read back as the program.
    private func written(_ program: Value) -> [Datum]? {
        guard
            let nodes = try? DocumentNode().nodes(of: program),
            let text = try? DatumWriter().text(of: nodes),
            let read = try? DatumReader().data(of: Array(text.unicodeScalars)),
            (try? DocumentNode().value(of: read[...], within: 1)) == program
        else {
            return nil
        }

        return nodes
    }
}
