//
//  Node.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A list read as a node: the word it begins with, which says which node it
// is, and the operands after it.
struct Node {
    // MARK: - Property
    let word: String
    let operands: [Datum]
    let offset: Int?

    // MARK: - Initializer
    init(_ datum: Datum) throws {
        guard case let .list(elements) = datum.form, let word = datum.word else {
            throw TextRefused("a node is written here, a word in parentheses before what it holds", at: datum.offset)
        }

        self.word = word
        self.operands = Array(elements.dropFirst())
        self.offset = datum.offset
    }

    // MARK: - Public
    func none() throws {
        guard operands.isEmpty else {
            throw TextRefused("`\(word)` holds nothing", at: operands[0].offset)
        }
    }

    func one() throws -> Datum {
        guard operands.count == 1 else {
            throw TextRefused("`\(word)` holds one operand, and here holds \(operands.count)", at: offset)
        }

        return operands[0]
    }

    // The operand after a name the node leads with, as `(field x 1)` holds.
    func named() throws -> (name: String, operand: Datum) {
        guard operands.count == 2 else {
            throw TextRefused("`\(word)` holds a name and one operand, and here holds \(operands.count)", at: offset)
        }

        return (try Node.name(operands[0]), operands[1])
    }

    // The name a node leads with and the parts after it, as a declaration
    // holds them.
    func declared() throws -> (name: String, parts: ArraySlice<Datum>) {
        guard let first = operands.first else {
            throw TextRefused("`\(word)` begins with a name", at: offset)
        }

        return (try Node.name(first), operands.dropFirst())
    }

    static func name(_ datum: Datum) throws -> String {
        guard case let .name(name) = datum.form else {
            throw TextRefused("a name is written here, bare or in backticks", at: datum.offset)
        }

        return name
    }

    // A name a text writes, through the door every name from outside a
    // program comes through, refused where it stands.
    static func name(_ spelling: String, at offset: Int?) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw TextRefused(refusal.message, at: offset)
        }
    }

    // MARK: - Private
}
