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
// does what the procedures in front of it let it do, and this is where a host
// writes down which procedures those may be. Closing a list against a catalogue
// reaches only what the host put in one.
//
// The link is not where this happens. It is handed a graph and holds one name
// to one declarer, and a graph holding two copies of a module gives that rule
// nothing to say about which copy was meant. Here the modules are rows of a
// table and a row is brought in once, so a second copy is not a thing that can
// be written.
//
// What a link needs is what a document discloses, said with the kind on it.
// `imports` is one list of spellings; a link asks which document declares a
// procedure and which declares a type, and a procedure and a type may share a
// spelling. So the needs are read off the module here, in both kinds, and one
// table answers them: the kind rides on the reference.
public struct Catalogue: Sendable {
    // MARK: - Property
    private let modules: [Module]

    // Which module declares each reference. One table, since every one of
    // them answers the same question and the kind rides on the reference.
    private let declares: [Reference: Int]

    // MARK: - Initializer
    // Two modules declaring one name is refused here, because a table that
    // holds the name twice cannot answer the one question this is asked. That
    // is a fact about the catalogue and not the link's rule stated again: the
    // link refuses such a pair only when both are in it, and a host may well
    // hold two modules it never puts in one graph.
    public init(_ modules: [Module]) throws {
        // One document at a time, in the order the host listed them, and each
        // document's declarations in reference order. So which collision is
        // reported is the host's list and then the document's own text.
        var declares: [Reference: Int] = [:]

        for (position, module) in modules.enumerated() {
            var collided: [(reference: Reference, first: Int)] = []

            for reference in module.declaredProcedures.map(Reference.procedure)
                + module.declaredTypes.map(Reference.type) {
                guard let first = declares[reference] else {
                    declares[reference] = position

                    continue
                }

                collided.append((reference, first))
            }

            // In reference order, which is why they are gathered rather than
            // thrown on as they are met: a catalogue that holds meets none of
            // them, and ordering what is never there is ordering nothing.
            guard let held = collided.min(by: { one, other in one.reference < other.reference }) else {
                continue
            }

            // Where it was written, read off the document here alone. A
            // catalogue that holds throws none of these, and a declaration's
            // place is what a refusal wants and nothing else does.
            let place = module.draft
                .declarations(in: .of(module))
                .first { declared in declared.reference == held.reference }?
                .place

            throw CatalogueError(
                "the \(held.reference.noun) '\(held.reference.name)' is declared by"
                    + " \(Place.Document.of(modules[held.first]).spelled(at: held.first)) and by"
                    + " \(Place.Document.of(module).spelled(at: position)) in this"
                    + " catalogue, so there is no answer to which one supplies it."
                    + " A catalogue names each declaration once",
                at: place ?? Place(in: .of(module))
            )
        }

        self.modules = modules
        self.declares = declares
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
    // whatever the caller listed, so a program declaring one procedure of a granted
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

        // Two walks, until neither adds anything. Names first, then claims,
        // because what a claim needs is spelled from the contract's procedures, and
        // the contract may be a document the name walk has only just brought.
        // Each walk on its own would answer for a list the other is still
        // growing.
        while true {
            let held = closed.count

            // Over the answer as it grows, so a module brought in for a name
            // is asked for its own needs in turn. Names in order, so which
            // modules arrive and where they stand is the same every time.
            while index < closed.count {
                let module = closed[index]
                index += 1

                for used in module.uses.sorted() {
                    bring(declares[used])
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
                for (contract, procedures) in module.contracts {
                    table[contract, default: []].formUnion(procedures.keys)
                }
            }

            // Which types the answer declares so far. A document leaning on a
            // pair names both of them, so a claim about two types this list
            // has is a claim this list may be leaning on, and the document
            // making it has to stand in the link for the pair to be answered.
            let named = closed.reduce(into: Set<Name>()) { names, module in
                names.formUnion(module.declaredTypes)
            }

            // A claim about two types nothing here pairs is brought as well.
            // Which pairs are really leaned on is read off bodies against the
            // signatures they call, which is a compile's answer and not a
            // list's.
            //
            // What that costs is the link's size: a host claiming widely about
            // a common vocabulary hands every link the same crowd. What it
            // does not cost is a refusal, since a claim whose procedures are
            // missing puts its type under no contract.
            for (position, module) in modules.enumerated() {
                let claims = module.claims

                guard
                    claims.contains(where: { type, contracts in
                        named.contains(type) && contracts.contains(where: { named.contains($0) })
                    })
                else {
                    continue
                }

                bring(position)
            }

            // A claim is answered by declarations named for its type and the
            // procedures its contract asks, and a document making one may declare
            // neither. The procedures are the contract's, which is why they are
            // read above rather than off the draft, which cannot see another
            // document's contract.
            for module in closed {
                for (type, contracts) in module.claims.sorted(by: { $0.key < $1.key }) {
                    for contract in contracts.sorted() {
                        for procedure in (asked[contract] ?? []).sorted() {
                            let spelling = ContractProcedure.spelling(
                                of: type,
                                procedure: procedure
                            )

                            bring(declares[.procedure(spelling)])
                        }
                    }
                }
            }

            guard closed.count > held else { return closed }
        }
    }

    // MARK: - Private
}
