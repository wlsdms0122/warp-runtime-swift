//
//  Builder+Contracting.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Which types answer which contracts, and whether the documents are good for
// what they said. A contract is the procedures a value must have, and a document
// says which types have them: the claim names a type and a contract, and the
// declaration behind each procedure is the one named for the type and the procedure,
// whose signature is the contract's with the receiver filled in by the type
// itself.
//
// Read off the claims and not off the whole shape space. A spelling that
// happens to join a type's name to a contract's procedure is that document's procedure
// until some document says otherwise, so what a link declares does not decide
// what an unrelated document may call things.
//
// A claim that does not hold puts its type under no contract, and where that
// is refused turns on whether another document could put it right. A name this
// list declares as a membership never becomes a contract, so the claim is
// refused where it is written. A procedure nothing declares may be in a document
// this list does not hold, so that reason waits beside the claim and is said
// to whoever leans on the pair.
//
// Every claim is read, not the reached ones, the way purity is worked out over
// every declaration. A slot bounded by a contract may be filled by a type no
// call in this link mentions.
extension Builder {
    // MARK: - Internal
    // For each contract, which declaration answers each of its procedures, keyed by
    // the type that satisfies it, and beside it the reason each claim that did
    // not hold does not.
    //
    // The run reads a row out of the first by the receiver's own name, and a
    // type standing in it has every procedure behind it.
    func witnesses(
        of claims: [Placed<Claim>],
        asking contracts: [Name: Placed<[Name: Signature]>],
        over types: [Name: Placed<TypeExpression>],
        among space: [Name: Placed<Signature>],
        in table: TypeTable
    ) throws -> (answering: [Name: [Name: [Name: Name]]], unheld: [Claim: String]) {
        // Every contract, answered or not. The entry is what says a name is a
        // contract at all, so a bound naming one no type answers stays a
        // different thing from a bound naming nothing.
        var gathered = contracts.keys.reduce(into: [Name: [Name: [Name: Name]]]()) { table, contract in
            table[contract] = [:]
        }
        var unheld: [Claim: String] = [:]

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
    // document the one leaning on it never names.
    //
    // A claim that was made and did not hold answers with its own reason. The
    // pair is written down and something behind it is wrong, which is a
    // different thing to fix from nobody having written it.
    func leaning(
        _ leaned: [Claim: Place],
        on satisfying: [Name: Set<Name>],
        unheld: [Claim: String]
    ) throws {
        for (claim, place) in leaned.sorted(by: { $0.key < $1.key }) {
            guard satisfying[claim.contract]?.contains(claim.type) != true else { continue }

            throw BuildError(
                unheld[claim]
                    ?? "hands '\(claim.type)' where '\(claim.contract)' is asked, and no"
                        + " document in this link says '\(claim.type)' answers it."
                        + " A type answers a contract because a document says so",
                at: place
            )
        }
    }

    // MARK: - Private
    // What a claim came to: the procedure behind each one the contract asks, or the
    // reason it came to nothing where another document could still supply it.
    private enum Holding {
        case holds([Name: Name])

        // The reason, not a refusal: this does not know the place a refusal
        // would stand at.
        case waits(String)
    }

    // One claim held to what stands behind it: the two names declared, every
    // procedure the contract asks answered by a declaration named for the type and
    // the procedure, and every one of those signatures the contract's with the
    // receiver filled in by the type itself.
    private func holding(
        _ claim: Placed<Claim>,
        asking contracts: [Name: Placed<[Name: Signature]>],
        over types: [Name: Placed<TypeExpression>],
        among space: [Name: Placed<Signature>],
        in table: TypeTable
    ) throws -> Holding {
        let (type, contract) = (claim.held.type, claim.held.contract)

        guard types[type] != nil else {
            let reason = "'\(type)' is not a type this link declares, and only a"
                + " type answers a contract"

            // Declared as something else here, which no document arriving
            // later undoes: one name has one declarer.
            guard contracts[type] == nil, table.constraint(type) == nil else {
                throw BuildError(reason, at: claim.place)
            }

            return .waits("\(claim.spelled) says " + reason)
        }

        guard let asked = contracts[contract] else {
            let reason = "'\(contract)' is not a contract this link declares,"
                + " so there are no procedures for '\(type)' to answer"

            guard types[contract] == nil, table.constraint(contract) == nil else {
                throw BuildError(reason, at: claim.place)
            }

            return .waits("\(claim.spelled) says " + reason)
        }

        var answering: [Name: Name] = [:]

        for (procedure, signature) in asked.held.sorted(by: { $0.key < $1.key }) {
            let spelling = ContractProcedure.spelling(of: type, procedure: procedure)

            guard let witness = space[spelling] else {
                return .waits(
                    "\(claim.spelled) says '\(type)' answers '\(contract)', which asks"
                        + " '\(procedure)', and nothing in this link declares '\(spelling)'."
                        + " A contract's procedure is answered by a declaration named"
                        + " for the type and the procedure"
                )
            }

            // The reason and not a refusal: a refusal renders its own place,
            // and this sentence stands where the pair was leaned on.
            if let reason = answers(
                signature,
                as: witness.held,
                receiving: type,
                of: contract,
                procedure: procedure,
                in: table
            ) {
                return .waits("\(witness.spelled) declares '\(spelling)', which " + reason)
            }

            answering[procedure] = spelling
        }

        return .holds(answering)
    }

    // One declaration held to one procedure of a contract.
    //
    // The claim says the declaration was meant to answer, so a signature that
    // misses is a reason the claim does not hold rather than the type quietly
    // standing outside. What has to change is this signature.
    private func answers(
        _ asked: Signature,
        as given: Signature,
        receiving type: Name,
        of contract: Name,
        procedure: Name,
        in table: TypeTable
    ) -> String? {
        guard let receiver = given.receiver, let held = given.parameters[receiver] else {
            return "is named for '\(type)' and the procedure '\(procedure)' that"
                    + " '\(contract)' asks, and takes no receiver. A contract's"
                    + " procedure is answered about the value it is sent to"
        }

        guard held.declared.lowered(in: table.loweredTypes)
            .same(TypeExpression.named(type).lowered(in: table.loweredTypes), in: table.loweredTypes)
        else {
            return "is named for '\(type)' and the procedure '\(procedure)' that '\(contract)'"
                    + " asks, and its receiver takes"
                    + " \(held.declared.rendered). A contract's procedure takes the"
                    + " type that answers it"
        }

        for (name, parameter) in asked.parameters.sorted(by: { $0.key < $1.key }) {
            guard let filled = given.parameters[name] else {
                return "is named for '\(type)' and the procedure '\(procedure)' that"
                        + " '\(contract)' asks, and declares no '\(name)'."
                        + " A call written against the contract hands that name"
            }

            guard filled.declared.lowered(in: table.loweredTypes)
                .same(parameter.declared.lowered(in: table.loweredTypes), in: table.loweredTypes)
            else {
                return "is named for '\(type)' and the procedure '\(procedure)' that"
                        + " '\(contract)' asks, and takes '\(name)' as"
                        + " \(filled.declared.rendered) where the contract"
                        + " writes \(parameter.declared.rendered)"
            }
        }

        // Anything the contract did not name and a call must fill is a name no
        // call written against the contract could write.
        for (name, parameter) in given.parameters.sorted(by: { $0.key < $1.key })
        where name != receiver && asked.parameters[name] == nil {
            guard
                parameter.default != nil
                    || parameter.declared.lowered(in: table.loweredTypes).declaresNull(in: table.loweredTypes)
            else {
                return "is named for '\(type)' and the procedure '\(procedure)' that"
                        + " '\(contract)' asks, and requires '\(name)', which"
                        + " the contract does not name. Nothing calling through"
                        + " the contract could fill it"
            }
        }

        guard let answer = asked.returns else { return nil }

        guard answer.lowered(in: table.loweredTypes)
            .accepts((given.returns ?? .any).lowered(in: table.loweredTypes), in: table.loweredTypes)
        else {
            return "is named for '\(type)' and the procedure '\(procedure)' that '\(contract)'"
                    + " asks, and answers \((given.returns ?? .any).rendered)"
                    + " where the contract writes \(answer.rendered)"
        }

        return nil
    }
}
