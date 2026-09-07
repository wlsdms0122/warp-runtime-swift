//
//  Catalogue.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The modules a host is willing to supply, and the world it hands a link.
//
// A module says what it asks for and never where to find it, so somebody has
// to decide which modules stand beside it. That decision is a grant: a program
// does what the words in front of it let it do, and this is where a host
// writes down which words those may be. Closing a list against a catalogue
// reaches only what the host put in one.
//
// The link is not where this happens. It is handed a world and holds one name
// to one declarer, and a world holding two copies of a module gives that rule
// nothing to say about which copy was meant. Here the names are keys of a
// table, so a second copy is not a thing that can be written.
public struct Catalogue: Sendable {
    // MARK: - Property
    private let modules: [Module]

    // Which module declares each name. Two tables because words and shapes are
    // two spaces: a link refuses one name standing for a shape and a
    // membership at once, and says nothing about a word spelled like a type.
    private let words: [Name: Int]
    private let shapes: [Name: Int]

    // MARK: - Initializer
    // Two modules declaring one name is refused here, because a table that
    // holds the name twice cannot answer the one question this is asked. That
    // is a fact about the catalogue and not the link's rule stated again: the
    // link refuses such a pair only when both are in it, and a host may well
    // hold two modules it never puts in one world.
    public init(_ modules: [Module]) throws {
        var words: [Name: Int] = [:]
        var shapes: [Name: Int] = [:]

        // In the order the host wrote them, each space walked whole, so which
        // collision is reported is a fact of that list and of nothing else.
        for (position, module) in modules.enumerated() {
            try Self.claim(
                module.declaredWords.sorted(),
                at: position,
                in: &words,
                of: module,
                calling: "word"
            )
        }

        for (position, module) in modules.enumerated() {
            try Self.claim(
                module.declaredShapes.sorted(),
                at: position,
                in: &shapes,
                of: module,
                calling: "shape"
            )
        }

        self.modules = modules
        self.words = words
        self.shapes = shapes
    }

    // MARK: - Public
    // The whole world for these modules: what was asked for, and everything in
    // the catalogue that what was asked for needs, and each of them once.
    //
    // A name nothing here declares is left alone. The link refuses it, naming
    // the world it looked in, and a refusal from here would be a second copy
    // of a rule that has to be right once.
    //
    // Modules the caller listed are not folded together. Two copies in that
    // list is a caller holding what it already had, and quietly keeping one of
    // them would make which one it is depend on the order they were written
    // in.
    public func world(for wanted: [Module]) -> [Module] {
        var world = wanted
        var declaredWords: Set<Name> = []
        var declaredShapes: Set<Name> = []

        func declare(_ module: Module) {
            declaredWords.formUnion(module.declaredWords)
            declaredShapes.formUnion(module.declaredShapes)
        }

        func bring(_ name: Name, from table: [Name: Int]) {
            guard let position = table[name] else { return }

            let supplier = modules[position]

            world.append(supplier)
            declare(supplier)
        }

        for module in wanted {
            declare(module)
        }

        // Over the world as it grows, so a module brought in for a name is
        // asked for its own needs in turn. Names in order, so which modules
        // arrive and where they stand is the same every time.
        var index = 0

        while index < world.count {
            let module = world[index]
            index += 1

            // The two spaces are asked separately because they are two tables,
            // and each name is asked against what stands in the world by then:
            // one module often supplies several of the names another needs.
            for name in module.imports.sorted() where !declaredWords.contains(name) {
                bring(name, from: words)
            }

            for name in module.mentions.sorted() where !declaredShapes.contains(name) {
                bring(name, from: shapes)
            }
        }

        return world
    }

    // MARK: - Private
    private static func claim(
        _ names: [Name],
        at position: Int,
        in table: inout [Name: Int],
        of module: Module,
        calling kind: String
    ) throws {
        for name in names {
            // A module claiming one spelling twice is one answer, not two: a
            // contract's word and a procedure of the same name in one module
            // still leave the catalogue with one module to hand back.
            if let first = table[name], first != position {
                throw CatalogueError(
                    "the \(kind) '\(name)' is declared by the modules at"
                        + " \(first) and \(position) in this catalogue, so there"
                        + " is no answer to which one supplies it. A catalogue"
                        + " names each declaration once",
                    at: Place(in: .of(module))
                )
            }

            table[name] = position
        }
    }
}
