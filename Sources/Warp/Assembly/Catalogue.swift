//
//  Catalogue.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The modules a host is willing to supply, and the graph it hands a link.
//
// A module says what it asks for and never where to find it, so somebody has
// to decide which modules stand beside it. That decision is a grant: a program
// does what the words in front of it let it do, and this is where a host
// writes down which words those may be. Closing a list against a catalogue
// reaches only what the host put in one.
//
// The link is not where this happens. It is handed a graph and holds one name
// to one declarer, and a graph holding two copies of a module gives that rule
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

    // Which module declares each reference. One table, since every one of
    // them answers the same question and the kind rides on the reference.
    private let declares: [Reference: Int]

    // Which modules declare a word a path could reach, under the last segment
    // alone, which is how a path names one.
    //
    // Narrowed to what a walk could arrive at, since a spelling no path can
    // reach is a candidate for nothing. Not narrowed further: whether a
    // written body answers without running is what it calls, so which of two
    // candidates a path really reaches is the link's to say, and this stands
    // both.
    private let walked: [Name: [Int]]

    // MARK: - Initializer
    // Two modules declaring one name is refused here, because a table that
    // holds the name twice cannot answer the one question this is asked. That
    // is a fact about the catalogue and not the link's rule stated again: the
    // link refuses such a pair only when both are in it, and a host may well
    // hold two modules it never puts in one graph.
    public init(_ modules: [Module]) throws {
        // Walked in reference order, so which collision is reported is a fact
        // of the list the host wrote and of nothing else.
        var declares: [Reference: Int] = [:]

        for (position, module) in modules.enumerated() {
            let declarations = module.draft.declarations(in: .of(module))

            for declaration in declarations.sorted(by: { $0.reference < $1.reference }) {
                guard let first = declares[declaration.reference] else {
                    declares[declaration.reference] = position

                    continue
                }

                throw CatalogueError(
                    "the \(declaration.reference.noun) '\(declaration.reference.name)' is declared by"
                        + " \(Place.Document.of(modules[first]).spelled(at: first)) and by"
                        + " \(Place.Document.of(module).spelled(at: position)) in this"
                        + " catalogue, so there is no answer to which one supplies it."
                        + " A catalogue names each declaration once",
                    at: declaration.place
                )
            }
        }

        // Which of them a path could reach, gathered before the tables so the
        // walked spellings are drawn from the same declarations.
        let walkable = modules.reduce(into: Set<Name>()) { names, module in
            names.formUnion(module.draft.walkableWords)
        }

        self.modules = modules
        self.declares = declares

        // Gathered, not claimed. Two candidates for one segment is not a
        // question this table fails to answer: it is a question whose answer
        // is the link's, and the link has what it takes to give it. Refusing
        // here would be that rule copied and made stricter than the original,
        // which refuses only what really is reachable twice.
        self.walked = declares
            .reduce(into: [Name: [Int]]()) { table, entry in
                guard case let .word(name) = entry.key, walkable.contains(name) else { return }

                table[name.unqualified, default: []].append(entry.value)
            }
            .mapValues { positions in positions.sorted() }
    }

    // MARK: - Public
    // These modules closed over what they need: what was asked for, and
    // everything in the catalogue that what was asked for needs, and each of
    // the catalogue's modules at most once.
    //
    // What is asked for is what the caller means to run. Supply belongs in the
    // catalogue, and a module handed over here as well as held there stands in
    // the answer twice, which the link refuses. Keeping the second one out
    // instead would mean a name the catalogue declares could be answered by
    // whatever the caller listed, so a program declaring one word of a granted
    // module would quietly become the module every other module calls.
    //
    // A name nothing here declares is left alone. The link refuses it, naming
    // the modules it looked in, and a refusal from here would be a second copy
    // of a rule that has to be right once.
    public func closing(_ wanted: [Module]) -> [Module] {
        var closed = wanted
        var taken: Set<Int> = []
        var index = 0

        func bring(_ position: Int?) {
            guard let position, taken.insert(position).inserted else { return }

            closed.append(modules[position])
        }

        func bring(_ positions: [Int]) {
            for position in positions {
                bring(position)
            }
        }

        // Two walks, until neither adds anything. Names first, then claims,
        // because what a claim needs is spelled from the contract's words, and
        // the contract may be a document the name walk has only just brought.
        // Each walk on its own would answer for a list the other is still
        // growing.
        while true {
            let held = closed.count

            // Over the answer as it grows, so a module brought in for a name
            // is asked for its own needs in turn. Names in order, so which
            // modules arrive and where they stand is the same every time.
            while index < closed.count {
                let draft = closed[index].draft
                index += 1

                for used in draft.uses.sorted() {
                    bring(declares[used])
                }

                for name in draft.walks.sorted() {
                    bring(walked[name] ?? [])
                }
            }

            // What each contract asks, read off the answer as this round found
            // it. Read once, so what this round follows is one list rather
            // than whatever the walk had brought by the time it reached each
            // claim. A contract that arrives during it is followed by the
            // next round.
            //
            // Every closed document declaring the name is read. Two declaring
            // one is the link's refusal, and choosing between them here would
            // be that rule copied and made to answer earlier.
            let asked = closed.reduce(into: [Name: Set<Name>]()) { table, module in
                for (contract, words) in module.contracts {
                    table[contract, default: []].formUnion(words.keys)
                }
            }

            // Which shapes the answer declares so far. A document leaning on a
            // pair names both of them, so a claim about two shapes this list
            // has is a claim this list may be leaning on, and the document
            // making it has to stand in the link for the pair to be answered.
            let named = closed.reduce(into: Set<Name>()) { names, module in
                names.formUnion(module.draft.declaredShapes)
            }

            // A claim about two shapes nothing here pairs is brought as well.
            // Which pairs are really leaned on is read off bodies against the
            // signatures they call, which is a compile's answer and not a
            // list's, and a table that guessed narrower would leave a link
            // refusing a pair the host was willing to answer.
            //
            // Bringing one this list cannot make good on costs nothing: a
            // claim whose words are missing puts its type under no contract
            // and refuses only the program that leans on the pair.
            //
            // What it does cost is the link's size, and the price is a
            // catalogue's claims about names the answer already holds. A host
            // whose catalogue claims widely about a common vocabulary hands
            // every link the same crowd, and the way out is a link asking a
            // compile which pairs were leaned on and closing again on those.
            for (position, module) in modules.enumerated() {
                let claiming = module.draft.claiming

                guard
                    claiming.contains(where: { type, contracts in
                        named.contains(type) && contracts.contains(where: { named.contains($0) })
                    })
                else {
                    continue
                }

                bring(position)
            }

            // A claim is answered by declarations named for its type and the
            // words its contract asks, and a document making one may declare
            // neither. The words are the contract's, which is why they are
            // read above rather than off the draft, which cannot see another
            // document's contract.
            for module in closed {
                for (type, contracts) in module.claiming.sorted(by: { $0.key < $1.key }) {
                    for contract in contracts.sorted() {
                        for word in (asked[contract] ?? []).sorted() {
                            bring(declares[.word(ContractWord.spelling(of: type, word: word))])
                        }
                    }
                }
            }

            guard closed.count > held else { return closed }
        }
    }

    // MARK: - Private
}
