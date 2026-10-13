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
// declaration behind each procedure is the type's member of that procedure's name,
// whose signature is the contract's with `Self` read as the type wherever it
// stands.
//
// Read off the claims and the members, and not off the whole type table: what
// answers is what a document gave the type, so what a link declares does not
// decide what an unrelated document may call things.
//
// A claim is judged where it is written, against what its document stands
// on: the names declared, and the type's members within that reach. One that
// does not hold is refused at the claim, whoever uses it. A document asking
// whether a type answers is answered by the claims within its own reach, so
// what a compile settles is a fact of the document and of what it stands on.
struct ClaimChecker {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Which types answer which contracts among `claims`, one claim each: the
    // table remade holding them, and the procedures the contracts ask under
    // the spellings a call writes to reach them.
    //
    // The table is remade holding the answer. Its rows are numbered from the
    // declarations alone, so a type lowered against either table is the same
    // type.
    func lowered(
        _ declaring: TypeTable,
        holding claims: [Placed<Claim>],
        in namespace: TypeNamespace,
        among signatures: [Name: Placed<Declared>],
        holdsEveryClaim: Bool = true
    ) throws -> (types: TypeTable, contractProcedures: [Name: LoweredContractProcedure]) {
        let table = try satisfying(declaring, holding: claims, in: namespace, holdsEveryClaim: holdsEveryClaim)

        // The procedures the contracts ask, under the spellings a call writes to
        // reach them. Read off the table the satisfaction was just written
        // into, so what a call reaches and what a judgement reads are one
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

        return (types: table, contractProcedures: contractProcedures)
    }

    // The table answering with `claims`, one claim each, every claim the link
    // holds or those within one document's reach. What a contract asks and
    // which spellings it takes are the declarations', so a table answering
    // with other claims asks the same procedures.
    func satisfying(
        _ declaring: TypeTable,
        holding claims: [Placed<Claim>],
        in namespace: TypeNamespace,
        holdsEveryClaim: Bool
    ) throws -> TypeTable {
        let kept = try Self.oneHeadEach(claims, over: namespace.types, in: declaring)
        let held = kept.reduce(
            into: namespace.contracts.keys.reduce(into: [Name: [Name: Head]]()) { table, contract in table[contract] = [:] }
        ) { table, placed in
            table[placed.held.contract]?[placed.held.type] = placed.held.head
        }

        return declaring.satisfying(held, holdsEveryClaim: holdsEveryClaim)
    }

    // What one document gives types, held to what stands behind it within
    // its reach: each head it extends a type under is a type a value is an
    // instance of, and each claim it makes holds. `members` are the members
    // given within the reach, and `space` the declarations a link resolves
    // spellings in, their facts standing where their rows do.
    func judge(
        _ claims: [Placed<Claim>],
        extending extended: [Placed<Head>],
        in namespace: TypeNamespace,
        members: Set<Name>,
        among space: [Name: Placed<Declared>],
        in table: TypeTable
    ) throws {
        // A type given members is a type a value is an instance of, the way a
        // type a claim is about is. One declared as something else is no
        // such type.
        for extended in extended {
            let type = extended.held.type

            if let reason = Self.refusal(of: type, over: namespace.types, asking: namespace.contracts, in: table) {
                throw BuildError(reason + ". Members are given to a struct, under the name it was declared", at: extended.place)
            }

            guard TypeExpression.nominalTypes[type] != nil || namespace.types[type] != nil else {
                throw BuildError("gives '\(type)' members, and '\(type)' is not a type this link declares", at: extended.place)
            }
        }

        for claim in claims {
            try holding(
                claim,
                asking: namespace.contracts,
                over: namespace.types,
                among: space,
                members: members,
                in: table
            )
        }
    }

    // MARK: - Private
    // The head a bare head stands for: its type applied to the type's own
    // parameters, held to the bounds the type holds them to. A head applying
    // its type, and a type taking no parameters, stand for themselves.
    private static func applying(_ head: Head, over types: [Name: Placed<TypeDeclaration>]) -> Head {
        guard head.isBare else { return head }

        switch head.type {
        case TypeSpelling.array:
            return Head(head.type, arguments: [.parameter(name: TypeSpelling.element)])

        case TypeSpelling.dictionary:
            return Head(
                head.type,
                arguments: [.parameter(name: TypeSpelling.key), .parameter(name: TypeSpelling.element)],
                bounds: [TypeSpelling.key: [TypeSpelling.hashable]]
            )

        default:
            guard case let .struct(_, typeParameters, bounds)? = types[head.type]?.held, !typeParameters.isEmpty else {
                return head
            }

            return Head(head.type, arguments: typeParameters.map { name in .parameter(name: name) }, bounds: bounds)
        }
    }

    // The claims a link holds, one for each type and contract. A type answers
    // a contract one way, so a second claim about the pair is the first where
    // its head takes the same values, each head's own type parameters read as
    // readings the other takes, and is refused where it is written otherwise.
    private static func oneHeadEach(
        _ claims: [Placed<Claim>],
        over types: [Name: Placed<TypeDeclaration>],
        in table: TypeTable
    ) throws -> [Placed<Claim>] {
        let loweredTypes = table.loweredTypes
        var first: [Name: [Name: Placed<Claim>]] = [:]
        var kept: [Placed<Claim>] = []

        for claim in claims {
            let (type, contract) = (claim.held.type, claim.held.contract)

            guard let earlier = first[type]?[contract] else {
                first[type, default: [:]][contract] = claim
                kept.append(claim)

                continue
            }

            let one = applying(earlier.held.head, over: types).lowered(in: loweredTypes)
            let other = applying(claim.held.head, over: types).lowered(in: loweredTypes)
            let same: Bool = switch (one, other) {
            case let (one?, other?):
                loweredTypes.refusal(of: one, under: other) == nil && loweredTypes.refusal(of: other, under: one) == nil

            default:
                one == other
            }

            guard same else {
                throw BuildError(
                    "says '\(claim.held.head.spelling)' answers '\(contract)', and \(earlier.spelled) says"
                        + " '\(earlier.held.head.spelling)' answers it. A type answers a contract one way,"
                        + " under one head",
                    at: claim.place
                )
            }
        }

        return kept
    }

    // Why a name is no type a value is an instance of, where this list says
    // what it is: a contract, or a declared name that is not itself a struct.
    // Nil for a type the language names, a struct, and a name nothing here
    // declares.
    private static func refusal(
        of type: Name,
        over types: [Name: Placed<TypeDeclaration>],
        asking contracts: [Name: Placed<[Name: ContractProcedure]>],
        in table: TypeTable
    ) -> String? {
        guard TypeExpression.nominalTypes[type] == nil else { return nil }

        if contracts[type] != nil {
            return "'\(type)' is a contract this link declares, and not a type"
        }

        guard types[type] != nil else { return nil }

        guard let row = table.loweredTypes.row(named: type), table.loweredTypes.declaresStruct(row) else {
            return "'\(type)' is not itself a struct, and no value is an instance of it under that name"
        }

        return nil
    }

    // One claim held to what stands behind it: the two names declared, every
    // procedure the contract asks answered by the type's member of that name
    // within what the claim's document stands on, and every one of those
    // signatures the contract's with `Self` read as the type wherever it
    // stands. Refused at the claim where it does not hold.
    private func holding(
        _ claim: Placed<Claim>,
        asking contracts: [Name: Placed<[Name: ContractProcedure]>],
        over types: [Name: Placed<TypeDeclaration>],
        among space: [Name: Placed<Declared>],
        members: Set<Name>,
        in table: TypeTable
    ) throws {
        let (type, contract) = (claim.held.type, claim.held.contract)
        let says = "says '\(type)' answers '\(contract)'"

        // A type the language names stands for itself, and one a document
        // declares for the struct behind it. A name declared here as
        // something else is no type: one name has one declarer.
        let languageType = TypeExpression.nominalTypes[type]

        if let reason = Self.refusal(of: type, over: types, asking: contracts, in: table) {
            throw BuildError(reason + ". A claim is about a struct, under the name it was declared", at: claim.place)
        }

        guard languageType != nil || types[type] != nil else {
            throw BuildError(
                says + ", and '\(type)' is not a type this link declares. Only a type answers a contract",
                at: claim.place
            )
        }

        guard let asked = contracts[contract] else {
            throw BuildError(
                "'\(contract)' is not a contract this link declares, so there are no procedures for '\(type)' to answer",
                at: claim.place
            )
        }

        // A claim is about the values its head takes: the type as the head
        // applies it, each of the head's own type parameters one no call
        // fills, held to the bounds the head writes. A bare head stands for
        // the type applied to its own parameters under the bounds the type
        // holds them to, so a claim about `Array` is about every list.
        let applied = Self.applying(claim.held.head, over: types).claimed
        let claimed = applied?.type ?? languageType ?? .named(type)
        let held = applied?.bounds ?? [:]
        let standing = applied?.standing ?? [:]

        for (procedure, wanted) in asked.held.sorted(by: { $0.key < $1.key }) {
            let spelling = procedure.spelled(under: type)

            // What answers is what a document the claim stands on gave the
            // type, so a procedure declared under the same spelling and given
            // to no type is not asked about.
            guard members.contains(spelling) else {
                throw BuildError(
                    says + ", which asks '\(procedure)', and nothing it stands on gives '\(type)' the member"
                        + " '\(procedure)'. A contract's procedure is answered by the type's member of that name",
                    at: claim.place
                )
            }

            // A private member is in no space another document resolves in,
            // and a contract is how a document that never names a declaration
            // calls it, so a private one backs no claim.
            guard let witness = space[spelling] else {
                throw BuildError(
                    says + ", which asks '\(procedure)', and the member '\(procedure)' is private to the document"
                        + " that gives it. A contract's procedure is called from any document,"
                        + " so a private member answers none",
                    at: claim.place
                )
            }

            if let reason = answers(
                wanted.signature,
                by: witness.held.signature,
                reading: witness.held.facts?.answer,
                answering: type,
                under: claim.held.head,
                claimed: claimed,
                holding: held,
                standing: standing,
                of: contract,
                procedure: procedure,
                in: table
            ) {
                throw BuildError(says + ", and \(witness.spelled) declares '\(spelling)', which " + reason, at: claim.place)
            }

            // What the contract asked beyond the signature, held where the
            // witness's row stands, which is where its document was compiled.
            guard let facts = witness.held.facts else { continue }

            if wanted.constness == .const, facts.constness != .const {
                throw BuildError(
                    says + ", and \(witness.spelled) declares '\(spelling)', which runs, and '\(contract)'"
                        + " asks '\(procedure)' to answer without running",
                    at: claim.place
                )
            }

            if wanted.isolation == .isolated, facts.isolation != .isolated {
                throw BuildError(
                    says + ", and \(witness.spelled) declares '\(spelling)', which touches a name another"
                        + " body could touch at once, and '\(contract)' asks '\(procedure)' to touch none",
                    at: claim.place
                )
            }

            if !facts.failing.fails(within: wanted.failing) {
                throw BuildError(
                    says + ", and \(witness.spelled) declares '\(spelling)', which may fail with"
                        + " \(facts.failing.rendered), and '\(contract)' lets '\(procedure)' fail with"
                        + " \(Failing.these(wanted.failing).rendered)",
                    at: claim.place
                )
            }
        }
    }

    // One declaration held to one procedure of a contract.
    //
    // The claim says the declaration was meant to answer, so a signature that
    // misses is a reason the claim does not hold rather than the type quietly
    // standing outside. What has to change is this signature.
    //
    // A call written against the contract lands on whichever declaration
    // answers, with what the contract's signature let it hand, and takes
    // back what that declaration answers. So each of the declaration's
    // positions stands where the contract's hands, the type first, and the
    // contract's answer takes what the declaration answers. The contract's
    // type parameters are its own and no call fills them here, so each
    // stands as one type the declaration does not know; the declaration's
    // own are filled by what the contract writes at the same positions. The
    // names are each declaration's own.
    //
    // A declaration that wrote no `returns` answers what the build read off
    // its body, which is `read`. A claim is judged once its document is
    // compiled, so every declaration it stands on has its reading.
    private func answers(
        _ asked: Signature,
        by given: Signature,
        reading read: LoweredType?,
        answering type: Name,
        under head: Head,
        claimed: TypeExpression,
        holding held: [Name: Set<Name>],
        standing: [Name: Name],
        of contract: Name,
        procedure: Name,
        in table: TypeTable
    ) -> String? {
        let loweredTypes = table.loweredTypes

        guard given.parameters.count == asked.parameters.count else {
            return "is the member '\(procedure)' of '\(type)', the procedure"
                    + " '\(contract)' asks, and takes \(given.parameters.count)"
                    + " parameters where the contract asks \(asked.parameters.count)"
        }

        // The contract's procedure as the claim reads it: `Self` is the type
        // the claim is about, wherever it stands, its own parameters held to
        // what the language holds them to.
        let replaced = asked.replacingSelf(with: claimed)
        let substituted = Signature(
            parameters: replaced.parameters,
            returns: replaced.returns,
            bounds: replaced.bounds.merging(held) { mine, _ in mine }
        )
        let takes = given.lowered(in: loweredTypes).map(\.type)
        let asks = substituted.lowered(in: loweredTypes).map(\.type)
        let substitution = Substitution(filling: takes, against: asks, in: loweredTypes)

        // What fills the declaration's own parameters is held to their bounds
        // the way a call's readings are: what each was read as, and each
        // reading of it that its join is not.
        for (parameter, names) in given.bounds.sorted(by: { $0.key < $1.key }) {
            let bounds = names.sorted()

            for reading in substitution.everyReading(of: parameter)
                where !LoweredType.composition(bounds).accepts(reading, in: loweredTypes) {
                // An element of a list or a map the claim is about is whatever
                // it holds, and a struct's parameter whatever a value of it is
                // applied to there, which no spelling of a document names.
                let read: String = switch reading {
                case .parameter(label: TypeSpelling.selfElement, bounds: []):
                    "whatever element a value of '\(type)' holds"

                case let .parameter(label, _) where standing[label] != nil:
                    "whatever a value of '\(type)' is applied to at '\(standing[label].map(\.spelling) ?? "")'"

                default:
                    reading.rendered(in: loweredTypes)
                }

                return "is the member '\(procedure)' of '\(type)', the procedure"
                        + " '\(contract)' asks, and reads '\(parameter)' as \(read)"
                        + " where its bounds \(bounds.map(\.spelling).joined(separator: " & ")) do not take it"
            }
        }

        for (position, (taken, handed)) in zip(takes, asks).enumerated()
            where !taken.filling(substitution.readings).takes(handed, in: loweredTypes) {
            guard position > 0 else {
                return "is the member '\(procedure)' of '\(type)', the procedure '\(contract)'"
                        + " asks, and takes \(taken.rendered(in: loweredTypes)) first, where a call"
                        + " through the contract hands it "
                        + (head.isBare ? "any value of '\(type)'" : "any value '\(head.spelling)' takes")
            }

            return "is the member '\(procedure)' of '\(type)', the procedure"
                    + " '\(contract)' asks, and takes \(taken.rendered(in: loweredTypes))"
                    + " at \(position) where the contract writes \(asked.parameters[position].type.rendered)"
        }

        guard
            let answer = asked.returns,
            let promised = substituted.returns?.lowered(in: loweredTypes, bounds: substituted.bounds)
        else {
            return nil
        }

        // What the declaration wrote is rendered as lowered, so a type
        // parameter names the bound its signature holds it to.
        let declared = given.returns?.lowered(in: loweredTypes, bounds: given.bounds)
        let answered = (declared ?? read ?? .any)
            .filling(substitution.readings)

        guard promised.accepts(answered, in: loweredTypes) else {
            return "is the member '\(procedure)' of '\(type)', the procedure '\(contract)'"
                    + " asks, and answers \((declared ?? answered).rendered(in: loweredTypes))"
                    + " where the contract writes \(answer.rendered)"
        }

        return nil
    }
}
