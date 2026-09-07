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
// nothing to say about which copy was meant. Here the modules are rows of a
// table and a row is brought in once, so a second copy is not a thing that can
// be written.
//
// What a link needs is not what a document discloses. `imports` says what the
// program can touch, which is the grant a caller reads before it allows
// anything; a link needs that and also the words a path steps to and the
// shapes a signature names, neither of which touches anything. So the needs
// are read off the module here, in three spellings, and each is looked up in
// the table it belongs to.
public struct Catalogue: Sendable {
    // MARK: - Property
    private let modules: [Module]

    // Which module declares each name, by the spelling a call writes.
    private let words: [Name: Int]

    // Which modules declare a word ending in each bare spelling. Several,
    // because a path reaches a word by its last segment alone, and which of
    // the declarations sharing one may be reached that way is settled by
    // purity and reachability. Both are read off the link, so what stands here
    // is every candidate and the link picks among them.
    private let walked: [Name: [Int]]

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
        var walked: [Name: [Int]] = [:]

        func claim(
            _ names: some Sequence<Name>,
            at position: Int,
            in table: inout [Name: Int],
            of space: Space,
            placing place: (Name) -> Place
        ) throws {
            for name in names.sorted() {
                guard let first = table[name] else {
                    table[name] = position

                    continue
                }

                throw CatalogueError(
                    "the \(space.spelled) '\(name)' is declared by"
                        + " \(Place.Document.of(modules[first]).spelled(at: first)) and by"
                        + " \(Place.Document.of(modules[position]).spelled(at: position)) in"
                        + " this catalogue, so there is no answer to which one supplies it."
                        + " A catalogue names each declaration once",
                    at: place(name)
                )
            }
        }

        // Each space walked whole before the next, so which collision is
        // reported is a fact of the list the host wrote and of nothing else.
        for (position, module) in modules.enumerated() {
            let draft = module.draft
            let document = Place.Document.of(module)

            try claim(draft.procedures.keys, at: position, in: &words, of: .word) { name in
                .procedure(name.spelling, in: document)
            }

            try claim(draft.contractWords, at: position, in: &words, of: .word) { name in
                .contract(name.spelling, in: document)
            }
        }

        for (position, module) in modules.enumerated() {
            let draft = module.draft
            let document = Place.Document.of(module)

            try claim(draft.types.keys, at: position, in: &shapes, of: .shape) { name in
                .type(name.spelling, in: document)
            }

            try claim(draft.constraints.keys, at: position, in: &shapes, of: .shape) { name in
                .constraint(name.spelling, in: document)
            }

            try claim(draft.contracts.keys, at: position, in: &shapes, of: .shape) { name in
                .contract(name.spelling, in: document)
            }
        }

        // Not claimed, gathered: a bare spelling shared by two declarations is
        // the ordinary case and the link tells them apart.
        for (name, position) in words {
            walked[name.unqualified, default: []].append(position)
        }

        self.modules = modules
        self.words = words
        self.walked = walked.mapValues { positions in positions.sorted() }
        self.shapes = shapes
    }

    // MARK: - Public
    // The whole world for these modules: what was asked for, and everything in
    // the catalogue that what was asked for needs, and each of the catalogue's
    // modules at most once.
    //
    // What is asked for is what the caller means to run. Supply belongs in the
    // catalogue, and a module handed over here as well as held there stands in
    // the world twice, which the link refuses. Keeping the second one out
    // instead would mean a name the catalogue declares could be answered by
    // whatever the caller listed, so a program declaring one word of a granted
    // module would quietly become the module every other module in the world
    // calls.
    //
    // A name nothing here declares is left alone. The link refuses it, naming
    // the world it looked in, and a refusal from here would be a second copy
    // of a rule that has to be right once.
    public func world(for wanted: [Module]) -> [Module] {
        var world = wanted
        var taken: Set<Int> = []
        var index = 0

        func bring(_ positions: [Int]) {
            for position in positions where taken.insert(position).inserted {
                world.append(modules[position])
            }
        }

        // Over the world as it grows, so a module brought in for a name is
        // asked for its own needs in turn. Names in order, so which modules
        // arrive and where they stand is the same every time.
        while index < world.count {
            let draft = world[index].draft
            index += 1

            for name in draft.sends.sorted() {
                bring(words[name].map { position in [position] } ?? [])
            }

            for name in draft.walks.sorted() {
                bring(walked[name] ?? [])
            }

            for name in draft.mentions.sorted() {
                bring(shapes[name].map { position in [position] } ?? [])
            }
        }

        return world
    }

    // MARK: - Private
}
