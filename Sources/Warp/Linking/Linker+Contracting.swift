//
//  Linker+Contracting.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Which types answer which contracts, and whether the documents are good for
// what they said. A contract is the words a value must have, and a document
// says which types have them: the claim names a type and a contract, and the
// declaration behind each word is the one named for the type and the word,
// whose signature is the contract's with the receiver filled in by the type
// itself.
//
// Read off the claims and not off the whole declaration space. A spelling that
// happens to join a type's name to a contract's word is that document's word
// until some document says otherwise, so what a link declares does not decide
// what an unrelated document may call things.
//
// A claim that does not hold puts its type under no contract, and what happens
// then depends on whether another document could put it right.
//
// A name declared as a membership is not going to become a contract: one name
// has one declarer, so nothing added later changes that answer, and the claim
// is refused where it is written. A word that is missing is a different thing
// entirely, since the document declaring it may simply not be in this list. A
// list is assembled from what a host was willing to supply, and one of its
// documents saying something this list cannot make good on says nothing about
// a program that never handed that type where that contract was asked. So that
// reason waits beside the claim for whoever leans on the pair.
//
// Every claim is read, not the reached ones, the way purity is worked out over
// every declaration. A slot bounded by a contract may be filled by a type no
// call in this link mentions.
extension Linker {
    // MARK: - Internal
    // For each contract, which declaration answers each of its words, keyed by
    // the type that satisfies it. The run reads a row out of this by the
    // receiver's own name, so what is gathered here is the whole of what a
    // call the link cannot settle will need.
    //
    // Read off the claims alone. Which declaration answers a word is the
    // spelling the type's name and the word's make, and that spelling is
    // known from the claim whether or not the declaration has arrived.
    // For each contract, which declaration answers each of its words, keyed by
    // the type that satisfies it, and beside it the reason each claim that did
    // not hold does not.
    //
    // The run reads a row out of the first by the receiver's own name, so what
    // is gathered there is the whole of what a call the link cannot settle
    // will need, and a type standing in it has every word behind it.
    func witnesses(
        of claims: [Declared<Claim>],
        asking contracts: [Name: Declared<[Name: Signature]>],
        over types: [Name: Declared<TypeExpression>],
        among space: [Name: Declared<Signature>],
        in table: TypeTable
    ) throws -> (answering: [Name: [Name: [Name: Name]]], unheld: [Claim: LinkError]) {
        // Every contract, answered or not. The entry is what says a name is a
        // contract at all, so a bound naming one no type answers stays a
        // different thing from a bound naming nothing.
        var gathered = contracts.keys.reduce(into: [Name: [Name: [Name: Name]]]()) { table, contract in
            table[contract] = [:]
        }
        var unheld: [Claim: LinkError] = [:]

        for claim in claims {
            let (type, contract) = (claim.held.type, claim.held.contract)

            switch try holding(claim, asking: contracts, over: types, among: space, in: table) {
            case let .holds(answering):
                gathered[contract]?[type] = answering

            case let .waits(reason):
                unheld[claim.held] = reason
            }
        }

        return (gathered, unheld)
    }

    // Every pair a document leaned on, answered by the claims of the whole
    // list.
    //
    // A compile writes these down instead of judging them: which types answer
    // a contract is read off the claims, and a claim may be written in a
    // document the one leaning on it never names. So the question waits for
    // the list that holds every claim there is.
    //
    // A claim that was made and did not hold answers with its own reason. The
    // author wrote the pair down and something behind it is wrong, which is a
    // different thing to fix from nobody having written it.
    func leaning(
        _ requiring: [Claim: Place],
        on satisfying: [Name: Set<Name>],
        unheld: [Claim: LinkError]
    ) throws {
        for (claim, place) in requiring.sorted(by: { $0.key < $1.key }) {
            guard satisfying[claim.contract]?.contains(claim.type) != true else { continue }

            if let refusal = unheld[claim] {
                throw refusal
            }

            throw LinkError(
                "hands '\(claim.type)' where '\(claim.contract)' is asked, and no"
                    + " document in this link says '\(claim.type)' answers it."
                    + " A type answers a contract because a document says so",
                at: place
            )
        }
    }

    // MARK: - Private
    // One claim held to what stands behind it: the two names declared, every
    // word the contract asks answered by a declaration named for the type and
    // the word, and every one of those signatures the contract's with the
    // receiver filled in by the type itself.
    // What a claim came to: the word behind each one the contract asks, or the
    // reason it came to nothing where another document could still supply it.
    private enum Holding {
        case holds([Name: Name])
        case waits(LinkError)
    }

    private func holding(
        _ claim: Declared<Claim>,
        asking contracts: [Name: Declared<[Name: Signature]>],
        over types: [Name: Declared<TypeExpression>],
        among space: [Name: Declared<Signature>],
        in table: TypeTable
    ) throws -> Holding {
        let (type, contract) = (claim.held.type, claim.held.contract)

        guard types[type] != nil else {
            // Declared as something else in this list, which no document
            // arriving later can undo: one name has one declarer.
            guard contracts[type] == nil, table.constraint(type) == nil else {
                throw LinkError(
                    "'\(type)' is not a type this link declares, and only a"
                        + " type answers a contract",
                    at: claim.place
                )
            }

            return .waits(
                LinkError(
                    "'\(type)' is not a type this link declares, and only a"
                        + " type answers a contract",
                    at: claim.place
                )
            )
        }

        guard let asked = contracts[contract] else {
            guard types[contract] == nil, table.constraint(contract) == nil else {
                throw LinkError(
                    "'\(contract)' is not a contract this link declares,"
                        + " so there are no words for '\(type)' to answer",
                    at: claim.place
                )
            }

            return .waits(
                LinkError(
                    "'\(contract)' is not a contract this link declares,"
                        + " so there are no words for '\(type)' to answer",
                    at: claim.place
                )
            )
        }

        var answering: [Name: Name] = [:]

        for (word, signature) in asked.held.sorted(by: { $0.key < $1.key }) {
            let spelling = ContractWord.spelling(of: type, word: word)

            guard let witness = space[spelling] else {
                return .waits(
                    LinkError(
                        "says '\(type)' answers '\(contract)', which asks '\(word)',"
                            + " and nothing in this link declares '\(spelling)'."
                            + " A contract's word is answered by a declaration named"
                            + " for the type and the word",
                        at: claim.place
                    )
                )
            }

            do {
                try answers(
                    signature,
                    as: witness.held,
                    receiving: type,
                    at: witness.place,
                    of: contract,
                    word: word,
                    in: table
                )
            } catch let refusal as LinkError {
                return .waits(refusal)
            }

            answering[word] = spelling
        }

        return .holds(answering)
    }

    // One declaration held to one word of a contract.
    //
    // The claim says the declaration was meant to answer, so a signature that
    // misses is refused rather than leaving the type quietly outside. The
    // refusal stands on the declaration: what has to change is the signature,
    // and the claim naming it is right about what it was for.
    private func answers(
        _ asked: Signature,
        as given: Signature,
        receiving type: Name,
        at place: Place,
        of contract: Name,
        word: Name,
        in table: TypeTable
    ) throws {
        guard let receiver = given.receiver, let held = given.parameters[receiver] else {
            throw LinkError(
                "is named for '\(type)' and the word '\(word)' that"
                    + " '\(contract)' asks, and takes no receiver. A contract's"
                    + " word is answered about the value it is sent to",
                at: place
            )
        }

        guard held.declared.lowered(in: table.shapes)
            .same(TypeExpression.named(type).lowered(in: table.shapes), in: table.shapes)
        else {
            throw LinkError(
                "is named for '\(type)' and the word '\(word)' that '\(contract)'"
                    + " asks, and its receiver takes"
                    + " \(held.declared.rendered). A contract's word takes the"
                    + " type that answers it",
                at: place
            )
        }

        for (name, parameter) in asked.parameters.sorted(by: { $0.key < $1.key }) {
            guard let filled = given.parameters[name] else {
                throw LinkError(
                    "is named for '\(type)' and the word '\(word)' that"
                        + " '\(contract)' asks, and declares no '\(name)'."
                        + " A call written against the contract hands that name",
                    at: place
                )
            }

            guard filled.declared.lowered(in: table.shapes)
                .same(parameter.declared.lowered(in: table.shapes), in: table.shapes)
            else {
                throw LinkError(
                    "is named for '\(type)' and the word '\(word)' that"
                        + " '\(contract)' asks, and takes '\(name)' as"
                        + " \(filled.declared.rendered) where the contract"
                        + " writes \(parameter.declared.rendered)",
                    at: place
                )
            }
        }

        // Anything the contract did not name and a call must fill is a name no
        // call written against the contract could write.
        for (name, parameter) in given.parameters.sorted(by: { $0.key < $1.key })
        where name != receiver && asked.parameters[name] == nil {
            guard
                parameter.default != nil
                    || parameter.declared.lowered(in: table.shapes).declaresNull(in: table.shapes)
            else {
                throw LinkError(
                    "is named for '\(type)' and the word '\(word)' that"
                        + " '\(contract)' asks, and requires '\(name)', which"
                        + " the contract does not name. Nothing calling through"
                        + " the contract could fill it",
                    at: place
                )
            }
        }

        guard let answer = asked.returns else { return }

        guard answer.lowered(in: table.shapes)
            .accepts((given.returns ?? .any).lowered(in: table.shapes), in: table.shapes)
        else {
            throw LinkError(
                "is named for '\(type)' and the word '\(word)' that '\(contract)'"
                    + " asks, and answers \((given.returns ?? .any).rendered)"
                    + " where the contract writes \(answer.rendered)",
                at: place
            )
        }
    }
}
