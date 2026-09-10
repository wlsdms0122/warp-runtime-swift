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
// Two passes, because the two answer to different things. What a type answers
// is what a document said, so a compile reads the claims and nothing else.
// Whether the declarations behind a claim are there and fit is a sentence
// about the link ("nothing in this link declares"), so it is asked once, where
// the whole list is in hand.
//
// Every claim is held, not the reached ones, the way purity is worked out over
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
    func witnesses(
        of claims: [Declared<Claim>],
        asking contracts: [Name: Declared<[Name: Signature]>]
    ) -> [Name: [Name: [Name: Name]]] {
        // Every contract, answered or not. The entry is what says a name is a
        // contract at all, so a bound naming one no type answers stays a
        // different thing from a bound naming nothing.
        var gathered = contracts.keys.reduce(into: [Name: [Name: [Name: Name]]]()) { table, contract in
            table[contract] = [:]
        }

        for claim in claims {
            let (type, contract) = (claim.held.type, claim.held.contract)

            guard let asked = contracts[contract] else { continue }

            gathered[contract]?[type] = asked.held.keys.reduce(into: [Name: Name]()) { words, word in
                words[word] = ContractWord.spelling(of: type, word: word)
            }
        }

        return gathered
    }

    // Every pair a document leaned on, held to a claim that says it holds.
    //
    // A compile writes these down instead of judging them: which types answer
    // a contract is read off the claims, and a claim may be written in a
    // document the one leaning on it never names. So the question waits for
    // the list that holds every claim there is.
    func leaning(
        _ requiring: [Claim: Place],
        on satisfying: [Name: Set<Name>]
    ) throws {
        for (claim, place) in requiring.sorted(by: { $0.key < $1.key }) {
            guard satisfying[claim.contract]?.contains(claim.type) != true else { continue }

            throw LinkError(
                "hands '\(claim.type)' where '\(claim.contract)' is asked, and no"
                    + " document in this link says '\(claim.type)' answers it."
                    + " A type answers a contract because a document says so",
                at: place
            )
        }
    }

    // Every claim held to what stands behind it.
    //
    // Asked where the whole list is in hand and nowhere else. Each of these
    // refusals is a sentence about the link, and a document compiled against
    // part of one would be told its claim is unanswered by a list that was
    // never asked to answer it.
    func backing(
        _ claims: [Declared<Claim>],
        asking contracts: [Name: Declared<[Name: Signature]>],
        over types: [Name: Declared<TypeExpression>],
        among space: [Name: Declared<Signature>],
        in table: TypeTable
    ) throws {
        for claim in claims {
            let (type, contract) = (claim.held.type, claim.held.contract)

            guard types[type] != nil else {
                throw LinkError(
                    "'\(type)' is not a type this link declares, and only a"
                        + " type answers a contract",
                    at: claim.place
                )
            }

            guard let asked = contracts[contract] else {
                throw LinkError(
                    "'\(contract)' is not a contract this link declares,"
                        + " so there are no words for '\(type)' to answer",
                    at: claim.place
                )
            }

            for (word, signature) in asked.held.sorted(by: { $0.key < $1.key }) {
                let spelling = ContractWord.spelling(of: type, word: word)

                guard let witness = space[spelling] else {
                    throw LinkError(
                        "says '\(type)' answers '\(contract)', which asks '\(word)',"
                            + " and nothing in this link declares '\(spelling)'."
                            + " A contract's word is answered by a declaration named"
                            + " for the type and the word",
                        at: claim.place
                    )
                }

                try answers(
                    signature,
                    as: witness.held,
                    receiving: type,
                    at: witness.place,
                    of: contract,
                    word: word,
                    in: table
                )
            }
        }
    }

    // MARK: - Private
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
