//
//  Linker+Contracting.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Which types answer which contracts. A contract is the words a value must
// have, and what a type has is what the link can see: a declaration named for
// the type and the word, whose signature is the contract's with the receiver
// filled in by the type itself.
//
// Worked out over every declaration rather than the reached ones, the way
// purity is. A slot bounded by a contract may be filled by a type no call in
// this link mentions.
extension Linker {
    // MARK: - Internal
    // For each contract, which declaration answers each of its words, keyed by
    // the type that satisfies it. The run reads a row out of this by the
    // receiver's own name, so what is gathered here is the whole of what a
    // call the link cannot settle will need.
    func witnesses(
        of contracts: [Name: Declared<[Name: Signature]>],
        over types: [Name: Declared<TypeExpression>],
        among space: [Name: Declared<Signature>],
        in table: TypeTable
    ) throws -> [Name: [Name: [Name: Name]]] {
        var gathered: [Name: [Name: [Name: Name]]] = [:]

        for (contract, declaration) in contracts.sorted(by: { $0.key < $1.key }) {
            var answering: [Name: [Name: Name]] = [:]

            for type in types.keys.sorted() {
                var words: [Name: Name] = [:]

                for (word, asked) in declaration.held.sorted(by: { $0.key < $1.key }) {
                    let spelling = ContractWord.spelling(of: type, word: word)

                    guard let witness = space[spelling] else { break }
                    guard
                        try answers(
                            asked,
                            as: witness.held,
                            receiving: type,
                            at: witness.place,
                            of: contract,
                            word: word,
                            in: table
                        )
                    else {
                        break
                    }

                    words[word] = spelling
                }

                guard words.count == declaration.held.count else { continue }

                answering[type] = words
            }

            gathered[contract] = answering
        }

        return gathered
    }

    // MARK: - Private
    // Whether one declaration answers one word of a contract.
    //
    // A declaration named for a type and a word is read as an attempt at the
    // contract, so a signature that misses is refused here rather than leaving
    // the type quietly outside. A spelling that collides by accident is the
    // cost, and it is the same cost every naming rule has.
    private func answers(
        _ asked: Signature,
        as given: Signature,
        receiving type: Name,
        at place: Place,
        of contract: Name,
        word: Name,
        in table: TypeTable
    ) throws -> Bool {
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

        guard let answer = asked.returns else { return true }

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

        return true
    }
}
