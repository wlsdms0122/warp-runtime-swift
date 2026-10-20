//
//  PathNode.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A path as a node, and the text a tree holds for it, `Path.rendered`. A
// name alone is the path of that one name.
//
//   x                                  x
//   (path a (field b) (field? c))      a.b?.c
//   (path a (index 0) (index? "k"))    a[0]?["k"]
//   (path a (index i) (index (path w (field at))))
//                                      a[i][w.at]
struct PathNode {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func text(of datum: Datum) throws -> String {
        let path = try self.path(of: datum, depth: 0)
        let rendered = path.rendered

        guard (try? PathParser().parse(rendered)) == path else {
            throw Unplaced(
                "'\(rendered)' reads back as another path: a name in it holds what a path is spelled with",
                at: datum.offset
            )
        }

        return rendered
    }

    // The node a tree's text is, where a node writes that text back.
    func datum(of text: String) throws -> Datum {
        let path: Path

        do {
            path = try PathParser().parse(text)
        } catch {
            throw Unplaced("the path is written '\(text)', which no node writes: \(error)")
        }

        let datum = try self.datum(of: path)

        guard (try? self.text(of: datum)) == text else {
            throw Unplaced("the path is written '\(text)', which no node writes. The nearest writes '\(path.rendered)'")
        }

        return datum
    }

    // MARK: - Private
    // A path's nodes nest no deeper than a tree may.
    private func path(of datum: Datum, depth: Int) throws -> Path {
        guard depth <= Value.nestingBound else {
            throw Unplaced("the path nests deeper than a document may", at: datum.offset)
        }

        if case let .name(name) = datum.form {
            return Path([.name(Name(normal: name))])
        }

        let node = try Node(datum)

        guard node.word == "path" else {
            throw Unplaced("a path is a name or `(path …)`, and here is `(\(node.word) …)`", at: node.offset)
        }

        let (head, parts) = try node.declared()

        guard !parts.isEmpty else {
            throw Unplaced("a path of one name is the name, written bare", at: node.offset)
        }

        var segments: [PathSegment] = [.name(Name(normal: head))]

        for part in parts {
            segments.append(try segment(part, depth: depth))
        }

        return Path(segments)
    }

    private func segment(_ datum: Datum, depth: Int) throws -> PathSegment {
        let node = try Node(datum)

        switch node.word {
        case "field", "field?":
            return .name(Name(normal: try Node.name(node.one())), optional: node.word == "field?")

        case "index", "index?":
            let index = try node.one()
            let optional = node.word == "index?"

            switch index.form {
            case let .int(position):
                return .index(.int(position), optional: optional)

            case let .text(key):
                return .index(.string(key), optional: optional)

            default:
                return .indexRef(try path(of: index, depth: depth + 1), optional: optional)
            }

        default:
            throw unsegmented(node)
        }
    }

    private func unsegmented(_ node: Node) -> Unplaced {
        Unplaced("a path's segment is `field`, `field?`, `index` or `index?`, and here is `\(node.word)`", at: node.offset)
    }

    private func datum(of path: Path) throws -> Datum {
        guard case let .name(head, false)? = path.segments.first else {
            throw Unplaced("the path '\(path.rendered)' begins with no unmarked name, and no node writes it")
        }

        guard path.segments.count > 1 else { return .name(head.spelling) }

        var parts: [Datum] = [.name(head.spelling)]

        for segment in path.segments.dropFirst() {
            parts.append(try datum(of: segment))
        }

        return .node("path", parts)
    }

    private func datum(of segment: PathSegment) throws -> Datum {
        switch segment {
        case let .name(name, optional):
            return .node(optional ? "field?" : "field", [.name(name.spelling)])

        case let .index(.int(position), optional):
            return .node(optional ? "index?" : "index", [Datum(.int(position))])

        case let .index(.string(key), optional):
            return .node(optional ? "index?" : "index", [Datum(.text(key))])

        case let .index(index, _):
            throw Unplaced("a path indexes by \(Rendering(index).text()), and no node writes it")

        case let .indexRef(path, optional):
            return .node(optional ? "index?" : "index", [try datum(of: path)])
        }
    }
}
