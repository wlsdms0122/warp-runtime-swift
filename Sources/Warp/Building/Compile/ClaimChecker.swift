//
//  ClaimChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// Which types answer which contracts, and whether the documents are good for
// what they said. A contract is the procedures a value must have, and a document
// says which types have them: the claim names a type and a contract, and the
// declaration behind each procedure is the one named for the type and the procedure,
// whose signature is the contract's with the first parameter taking the type
// itself.
//
// Read off the claims and not off the whole type table. A spelling that
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
// Every claim is read, not the reached ones, the way constness is worked out over
// every declaration. A slot bounded by a contract may be filled by a type no
// call in this link mentions.
struct ClaimChecker {
    // What a claim came to: the procedure behind each one the contract asks, or the
    // reason it came to nothing where another document could still supply it.
    private enum Holding {
        case holds([Name: Name])

        // The reason, not a refusal: this does not know the place a refusal
        // would stand at.
        case waits(String)
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
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

    // Which types answer which contracts, read off what the documents claimed.
    //
    // The table is remade holding the answer. Its rows are numbered from the
    // declarations alone, so a type lowered against either table is the same
    // type.
    func lowered(
        _ declaring: TypeTable,
        claims: [Placed<Claim>],
        contracts: [Name: Placed<[Name: ContractProcedure]>],
        over declaredTypes: [Name: Placed<TypeExpression>],
        among signatures: [Name: Placed<Declared>],
        concealed: Set<Name> = [],
        unsettled: Fulfillment? = nil
    ) throws -> (
        types: TypeTable,
        contractProcedures: [Name: LoweredContractProcedure],
        unheld: [Claim: String]
    ) {
        // The witnesses are judged against a table that says which types
        // answer which contracts, so a contract named in a contract's own
        // signature stands as one, and an answer that leans on a claim is
        // held to what holds. What holds is read off the claims and cut down
        // to what the witnesses hold up, until nothing more falls: a claim
        // that leans on one that fell falls with it.
        var held = claims.reduce(
            into: contracts.keys.reduce(into: [Name: Set<Name>]()) { table, contract in table[contract] = [] }
        ) { table, placed in
            guard table[placed.held.contract] != nil else { return }

            table[placed.held.contract]?.insert(placed.held.type)
        }
        var table: TypeTable
        var witnessed: (answering: [Name: [Name: [Name: Name]]], unheld: [Claim: String])

        // The table the last pass was judged against holds exactly what the
        // witnesses hold up, so it is the table the link reads.
        repeat {
            table = declaring.satisfying(held, unsettled: unsettled)
            witnessed = try witnesses(
                of: claims,
                asking: contracts,
                over: declaredTypes,
                among: signatures,
                concealed: concealed,
                in: table
            )

            let answering = witnessed.answering.mapValues { answering in Set(answering.keys) }

            guard answering != held else { break }

            held = answering
        } while true

        // The procedures the contracts ask, under the spellings a call writes to
        // reach them. Read off the table the satisfaction was just written
        // into, so what a call reaches and what a judgment reads are one
        // reading rather than two.
        let contractProcedures = LoweredContractProcedure.table(in: table)

        // A contract's procedure and a declaration cannot take one spelling. A call
        // writing it lowers to the pick the contract makes, so the declaration
        // standing under it is reachable by nothing and the two readings of
        // one name never meet.
        //
        // In name order, so which collision is reported first is the text's
        // fact rather than a hash seed's.
        if
            let spelling = contractProcedures.keys.sorted()
                .first(where: { taken in signatures[taken] != nil }),
            let declared = signatures[spelling],
            let asked = contractProcedures[spelling]
        {
            throw BuildError(
                "'\(spelling)' is declared by \(declared.spelled) and asked as a procedure"
                    + " of '\(asked.contract)', so there is no answer to which one a"
                    + " call reaches. A contract's procedure and a declaration cannot take"
                    + " one spelling",
                at: declared.place
            )
        }

        return (
            types: table,
            contractProcedures: contractProcedures,
            unheld: witnessed.unheld
        )
    }

    // MARK: - Private
    // For each contract, which declaration answers each of its procedures, keyed by
    // the type that satisfies it, and beside it the reason each claim that did
    // not hold does not.
    //
    // The run reads a row out of the first by the name its first argument
    // wears, and a type standing in it has every procedure behind it.
    private func witnesses(
        of claims: [Placed<Claim>],
        asking contracts: [Name: Placed<[Name: ContractProcedure]>],
        over types: [Name: Placed<TypeExpression>],
        among space: [Name: Placed<Declared>],
        concealed: Set<Name>,
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

            switch try holding(claim, asking: contracts, over: types, among: space, concealed: concealed, in: table) {
            case let .holds(answering):
                gathered[contract]?[type] = answering

            case let .waits(reason):
                unheld[claim.held] = reason
            }
        }

        return (gathered, unheld)
    }

    // One claim held to what stands behind it: the two names declared, every
    // procedure the contract asks answered by a declaration named for the type and
    // the procedure, and every one of those signatures the contract's with the
    // first parameter taking the type itself.
    private func holding(
        _ claim: Placed<Claim>,
        asking contracts: [Name: Placed<[Name: ContractProcedure]>],
        over types: [Name: Placed<TypeExpression>],
        among space: [Name: Placed<Declared>],
        concealed: Set<Name>,
        in table: TypeTable
    ) throws -> Holding {
        let (type, contract) = (claim.held.type, claim.held.contract)

        guard types[type] != nil else {
            let reason = "'\(type)' is not a type this link declares, and only a"
                + " type answers a contract"

            // Declared as something else here, which no document arriving
            // later undoes: one name has one declarer.
            guard contracts[type] == nil, table.constraints[type] == nil else {
                throw BuildError(reason, at: claim.place)
            }

            return .waits("\(claim.spelled) says " + reason)
        }

        guard let asked = contracts[contract] else {
            let reason = "'\(contract)' is not a contract this link declares,"
                + " so there are no procedures for '\(type)' to answer"

            guard types[contract] == nil, table.constraints[contract] == nil else {
                throw BuildError(reason, at: claim.place)
            }

            return .waits("\(claim.spelled) says " + reason)
        }

        // A value written `linear` is followed by the name that holds it, and
        // a contract standing where a type is written holds a value under no
        // name of its own.
        guard !TypeExpression.named(type).handedOnce(in: table) else {
            throw BuildError(
                "'\(type)' is handed on once and answers no contract. A value written"
                    + " `linear` is followed by the name that holds it, and a contract"
                    + " standing where a type is written holds a value under no name",
                at: claim.place
            )
        }

        var answering: [Name: Name] = [:]

        for (procedure, wanted) in asked.held.sorted(by: { $0.key < $1.key }) {
            let spelling = ContractProcedure.spelling(of: type, procedure: procedure)

            // A private declaration is in no space another document resolves
            // in, and a contract is how a document that never names a
            // declaration calls it, so a private one backs no claim.
            guard let witness = space[spelling] else {
                guard !concealed.contains(spelling) else {
                    return .waits(
                        "\(claim.spelled) says '\(type)' answers '\(contract)', which asks"
                            + " '\(procedure)', and '\(spelling)' is private to the document that"
                            + " declares it. A contract's procedure is called from any document,"
                            + " so a private declaration answers none"
                    )
                }

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
                wanted.signature,
                as: witness.held.signature,
                reading: witness.held.facts?.answer,
                answering: type,
                of: contract,
                procedure: procedure,
                at: claim.place,
                in: table
            ) {
                return .waits("\(witness.spelled) declares '\(spelling)', which " + reason)
            }

            // What the contract asked beyond the signature, held where the
            // witness's row stands. A declaration being compiled now has no
            // row yet, and the link holds it when every row does.
            if let facts = witness.held.facts {
                if wanted.constness == .const, facts.constness != .const {
                    return .waits(
                        "\(witness.spelled) declares '\(spelling)', which runs, and '\(contract)'"
                            + " asks '\(procedure)' to answer without running"
                    )
                }

                if wanted.isolation == .isolated, facts.isolation != .isolated {
                    return .waits(
                        "\(witness.spelled) declares '\(spelling)', which touches a name another"
                            + " body could touch at once, and '\(contract)' asks '\(procedure)' to touch none"
                    )
                }
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
    //
    // A declaration that wrote no `returns` answers what the build read off
    // its body, which is `read`. A declaration being compiled now has no
    // reading yet, and the link holds it when every row has one.
    private func answers(
        _ asked: Signature,
        as given: Signature,
        reading read: LoweredType?,
        answering type: Name,
        of contract: Name,
        procedure: Name,
        at place: Place,
        in table: TypeTable
    ) -> String? {
        guard let held = given.parameters.first else {
            return "is named for '\(type)' and the procedure '\(procedure)' that"
                    + " '\(contract)' asks, and takes nothing. A contract's"
                    + " procedure is answered about the value it takes first"
        }

        guard held.declared.lowered(in: table.loweredTypes)
            .same(TypeExpression.named(type).lowered(in: table.loweredTypes), in: table.loweredTypes)
        else {
            return "is named for '\(type)' and the procedure '\(procedure)' that '\(contract)'"
                    + " asks, and takes \(held.declared.rendered) first. A contract's"
                    + " procedure takes the type that answers it first"
        }

        guard given.parameters.count == asked.parameters.count else {
            return "is named for '\(type)' and the procedure '\(procedure)' that"
                    + " '\(contract)' asks, and takes \(given.parameters.count)"
                    + " parameters where the contract asks \(asked.parameters.count)"
        }

        // After the first, the witness takes what the contract asks at the
        // same positions: a call written against the contract lands on
        // whichever declaration answers, and the run hands the arguments to
        // the same positions for every one of them. The names are each
        // declaration's own.
        for (position, (parameter, filled)) in zip(asked.parameters, given.parameters).enumerated().dropFirst() {
            guard filled.declared.lowered(in: table.loweredTypes)
                .same(parameter.declared.lowered(in: table.loweredTypes), in: table.loweredTypes)
            else {
                return "is named for '\(type)' and the procedure '\(procedure)' that"
                        + " '\(contract)' asks, and takes \(filled.declared.rendered)"
                        + " at \(position) where the contract writes \(parameter.declared.rendered)"
            }
        }

        guard let answer = asked.returns else { return nil }

        let promised = answer.lowered(in: table.loweredTypes)
        let answered = given.returns?.lowered(in: table.loweredTypes)
            ?? read
            ?? TypeExpression.any.lowered(in: table.loweredTypes)

        guard promised.accepts(answered, in: table.loweredTypes) else {
            return "is named for '\(type)' and the procedure '\(procedure)' that '\(contract)'"
                    + " asks, and answers \(given.returns?.rendered ?? answered.rendered(in: table.loweredTypes))"
                    + " where the contract writes \(answer.rendered)"
        }

        // A composition the answer is held to, wherever in the promise it
        // stands, is held the way a slot holds what arrives. Nothing is
        // written down: a witness reads what the documents say, and where
        // they are all in what they say is settled.
        if let refusal = TypeChecker().refusal(
            holding: answered,
            to: promised,
            as: "is named for '\(type)' and the procedure '\(procedure)' that '\(contract)' asks, and answers",
            in: table.loweredTypes,
            fulfillment: nil,
            at: place
        ) {
            return refusal
        }

        return nil
    }
}
