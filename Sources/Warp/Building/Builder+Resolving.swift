//
//  Builder+Resolving.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Turning what the documents wrote into what the link asks: the declarations
// gathered under their declared spellings, the type and constraint tables the
// judgments read against, and the module-level constants and variables settled
// in the order they read each other.
extension Builder {
    // MARK: - Internal
    // Which types answer which contracts, read off what the documents claimed.
    //
    // The table is remade holding the answer. Its rows are numbered from the
    // declarations alone, so a type lowered against either table is the same
    // type.
    func lowered(
        _ declaring: TypeTable,
        claims: [Placed<Claim>],
        contracts: [Name: Placed<[Name: Signature]>],
        over declaredTypes: [Name: Placed<TypeExpression>],
        among signatures: [Name: Placed<Declared>],
        concealed: Set<Name> = [],
        unsettled: Fulfillment? = nil
    ) throws -> (
        types: TypeTable,
        contractProcedures: [Name: ContractProcedure],
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
        let contractProcedures = ContractProcedure.table(in: table)

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

    // No document twice. An identity is derived from the text, so two copies of
    // one are one document, and every name in it collides with itself.
    //
    // Refused here rather than left to the collision, because the collision has
    // nothing to say: both sides of its sentence are the same document, and the
    // fix is not a spelling but a caller holding what it already had.
    //
    // What the caller already compiled counts: those documents are in this
    // link too, and handing one over again is the same document twice however
    // it arrived.
    func once(_ modules: [Module], held: Set<Identity> = []) throws {
        var held = held

        for module in modules {
            guard let identity = module.identity else { continue }
            guard held.insert(identity).inserted else {
                throw BuildError(
                    "this document was handed to the build twice. A build states"
                        + " its whole graph once, so a document already in it is"
                        + " not something to add",
                    at: Place(in: .of(module))
                )
            }
        }
    }

    // Every declaration under the spelling it was declared by. Two modules
    // cannot both declare one spelling, for the same reason two `.c` files
    // cannot both define a symbol.
    func symbols(of modules: [Module], after held: Int = 0) throws -> [Symbol] {
        var symbols: [Symbol] = []

        // The declaration that took each name, rather than only that the name
        // is taken. A refusal about a name declared twice is addressed to the
        // declaration that cannot be added and names both in the sentence. A
        // set answers neither half, and the place alone answers neither when
        // the two documents were never written down.
        var claimed: [Name: Symbol] = [:]

        for (origin, module) in modules.enumerated() {
            for name in module.procedures.keys.sorted() {
                guard let procedure = module.procedures[name] else { continue }

                let symbol = Symbol(
                    declared: name,
                    document: .of(module),
                    origin: origin,
                    handed: held + origin,
                    procedure: procedure
                )

                if let first = claimed[name], symbol.supplies {
                    throw BuildError(
                        "'\(name)' is declared more than once in this link, by"
                            + " \(first.spelled) and \(symbol.spelled). Two declarations"
                            + " of a name have no way to be told apart",
                        at: symbol.place
                    )
                }

                if symbol.supplies {
                    claimed[name] = symbol
                }

                symbols.append(symbol)
            }
        }

        return symbols
    }

    // Every type the modules declared, and the check that each name a
    // declaration mentions is one of them. A type name is resolved here for the
    // same reason a procedure name is: unreached code still has to compile, and
    // a signature naming a type nobody declared is a defect whether or not
    // this run walks that way. The spaces arrive gathered from the qualifying
    // pass. The one place their uniqueness is refused, so what this judges is
    // what that fact was proved on. This judges content: what a declaration
    // holds, not what it is called.
    func types(
        declared: [Name: Placed<TypeExpression>],
        constraints members: [Name: Placed<[TypeExpression]>],
        contracts: [Name: Placed<[Name: Signature]>],
        of documents: [any Declaring],
        standing: [Int],
        numbered linkage: Linkage
    ) throws -> TypeTable {
        // A document's types and its memberships each take a run of type rows
        // the way its declarations take a run of table rows, in the standing
        // order, so a document's types are behind the types it names.
        let table = TypeTable(
            types: declared.mapValues(\.held),
            constraints: members.mapValues(\.held),
            contracts: contracts.mapValues(\.held),
            standing: standing.flatMap { position in documents[position].types.keys.sorted() },
            constraintStanding: standing.flatMap { position in
                documents[position].constraints.keys.sorted()
            },
            of: linkage
        )

        // A name that reaches a type may name itself along the way: `Tree`
        // holding `array<Tree>` is a type. A name that reaches only names
        // never becomes one, and the lowering says which do, so the refusal
        // reads the lowering rather than walking the names a second way.
        // Refused first, so every walk below through `named` is finite.
        // In name order rather than the rows', so which of two names that
        // name themselves is reported does not follow how the documents were
        // handed over.
        for label in table.loweredTypes.cycling.map({ row in table.loweredTypes.labels[row] }).sorted() {
            guard let declaration = declared[label] else { continue }

            throw BuildError(
                "reaches itself through nothing but names, and a name"
                    + " that only names names never reaches a type",
                at: declaration.place
            )
        }

        for (_, declaration) in members.sorted { $0.key < $1.key } {
            let admitted = declaration.held

            guard !admitted.isEmpty else {
                throw BuildError(
                    "admits nothing, so no parameter it"
                        + " bounds could ever be filled",
                    at: declaration.place
                )
            }

            // A member is a concrete type. `some` stands for a type and names
            // none, `any` would admit everything a membership exists to narrow,
            // and `never` admits nothing. Each is a declaration that says
            // nothing a membership could hold, and a member that names another
            // constraint is what keeps the membership judgment from ever
            // chasing itself. Judged through every name a member hides behind,
            // or one alias would carry the refused type in. The chain is
            // finite because a name-only cycle was refused above.
            for member in admitted {
                var resolved = member

                while case let .named(next) = resolved, let underneath = declared[next] {
                    resolved = underneath.held
                }

                // A name left standing names no declared type: another
                // membership, which is a set of types and stands; a
                // contract, which is not a type; or nothing, which the
                // mention below refuses by its own name.
                let concrete = switch resolved {
                case let .named(name): contracts[name] == nil
                case .parameter, .any, .never, .composition: false
                case .null, .bool, .int, .double, .string, .ranged, .array,
                    .dictionary, .record, .procedure, .variable, .inout, .linear, .consuming,
                    .borrowing, .nullable, .reading: true
                }

                guard concrete else {
                    throw BuildError(
                        "a member is a concrete type."
                            + " `\(member.rendered)` says nothing a"
                            + " membership could hold",
                        at: declaration.place
                    )
                }
            }
        }

        // The two tables are walked whole rather than per module:
        // they arrive carrying where each name was written, and asking a module
        // again would be spelling that a second way.
        for (_, declaration) in declared.sorted { $0.key < $1.key } {
            try mentioned(
                in: declaration.held,
                at: declaration.place,
                parameterized: false,
                declaring: true,
                resolve: table
            )
        }

        for (_, declaration) in members.sorted { $0.key < $1.key } {
            for member in declaration.held {
                try mentioned(
                    in: member,
                    at: declaration.place,
                    parameterized: false,
                    resolve: table
                )
            }
        }

        return table
    }

    // Every type a document names, held to being one the link declares. A
    // document is read on its own: what is judged is its own text, and the
    // table is what the whole link declared.
    func judge(_ modules: [Module], in table: TypeTable) throws {
        try judge(memberships: modules, in: table)

        for module in modules {
            for (name, procedure) in module.procedures.sorted { $0.key < $1.key } {
                try judge(procedure.signature, at: .procedure(name.spelling, in: .of(module)), in: table)

                // A closure literal carries a signature the way a declaration
                // does, and unreached code still has to compile, so what the
                // top level is held to, a signature written inline is held to
                // in the same pass, wherever a body buries it.
                if case let .body(block) = procedure.implementation {
                    try judge(subexpressions: block, at: .procedure(name.spelling, in: .of(module)), in: table)
                }
            }

            // A contract's procedures are declarations the way the module's
            // own are, and what a call is judged against is what was judged.
            for (contract, procedures) in module.contracts.sorted(by: { $0.key < $1.key }) {
                for (name, signature) in procedures.sorted(by: { $0.key < $1.key }) {
                    try judge(signature, at: .contract(contract.spelling, in: .of(module)).key(name.spelling), in: table)
                }
            }

            for (name, constant) in module.constants.sorted { $0.key < $1.key } {
                try judge(subexpressions: constant, at: .constant(name.spelling, in: .of(module)), in: table)
            }

            for (name, variable) in module.variables.sorted { $0.key < $1.key } {
                try judge(subexpressions: variable, at: .variable(name.spelling, in: .of(module)), in: table)
            }
        }
    }

    // A membership is handed on once when every member is, so one that mixes
    // has no answer: a value of it would carry an obligation on some readings
    // and not on others, and which it was is exactly what a membership does not
    // say.
    //
    // Asked of every module before any procedure is judged, and in name order,
    // because a slot naming such a membership reads its answer off this. A
    // procedure judged first would be told its slot is the mistake, and the
    // mistake is the declaration.
    private func judge(memberships modules: [Module], in table: TypeTable) throws {
        let declared = modules
            .flatMap { module in module.constraints.map { name, members in (name, members, module) } }
            .sorted { one, other in one.0 < other.0 }

        for (name, members, module) in declared {
            let (handed, rest) = members.reduce(into: ([TypeExpression](), [TypeExpression]())) { split, member in
                if Builder.handedOnce(member, in: table) {
                    split.0.append(member)
                } else {
                    split.1.append(member)
                }
            }

            guard !handed.isEmpty, !rest.isEmpty else { continue }

            throw BuildError(
                "admits \(handed.map(\.rendered).sorted().joined(separator: " and ")),"
                    + " which is handed on exactly once, beside"
                    + " \(rest.map(\.rendered).sorted().joined(separator: " and ")),"
                    + " which is not. A value of a membership is followed the same"
                    + " way whichever member it is",
                at: .constraint(name.spelling, in: .of(module))
            )
        }
    }

    // A document's constants, settled. They are evaluated here because there is
    // nothing about them left for a run to do: a constant sees no scope, so what
    // it will be is knowable the moment the document is read.
    //
    // One may name another declared beside it, so they are settled in the order
    // they read each other and that order is worked out first. What is wrong
    // with a set of constants is a fact about that order, and asking the order
    // is the whole of finding it.
    func constants(
        of module: Module,
        at origin: Int,
        folding answered: Answered,
        writing lowering: inout Lowering,
        leaning fulfillment: Fulfillment,
        in context: TypingContext
    ) async throws -> [Name: Value] {
        // Folding runs what it reads, and running reads rows. A lowered body
        // carries its document's own numbers, so the table handed here is one
        // that says which row each of those numbers stands for.
        //
        // The context is the document's own, since a document reads its own
        // constants, and it is handed over rather than asked for: the lowering
        // this writes into is one of the tables a context is read off.
        guard !module.constants.isEmpty else { return [:] }

        var known: [Name: Value] = [:]

        // Handed over with what each one reads, so nothing looks a name
        // back up in the table the order was read from. Everything this one
        // needs comes before it, and asking again is a second chance to ask
        // a different table.
        for (name, expression) in try order(module.constants, in: module) {
            let place = Place.constant(name.spelling, in: .of(module))

            try await fulfillment.folding(place) {
                // A constant's dots are judged before it settles, the way a
                // body's are: the settled neighbours' types are the
                // environment, so an absent field or a needless `?.` refuses
                // here by the one rule, and carries its own place.
                let (judged, calls) = try await resolvedSites(
                    in: expression,
                    at: place,
                    in: known.mapValues { value in .fixed(type(of: value, in: context.loweredTypes)) },
                    with: context,
                    folding: nil,
                    writing: fulfillment
                )

                // A closure a constant holds runs later, so evaluating the
                // constant proves nothing about the sends inside it. They pass
                // the same gate every gathered call does.
                try checked(calls, in: context, writing: fulfillment)

                // A constant settles at the build, so what it is written from
                // is read rather than run. The same gate an operand passes,
                // asked here because a constant is the one other place the
                // build reads an expression instead of running it.
                try settles(judged, at: place, given: context, writing: fulfillment)

                do {
                    known[name] = try await Folding(
                        constants: known,
                        origin: origin,
                        in: answered,
                        loweredTypes: context.loweredTypes
                    ).read(judged, as: name, writing: &lowering, at: place)
                } catch let refused as BuildError {
                    throw refused
                } catch {
                    throw BuildError("\(error)", at: place)
                }
            }
        }

        return known
    }

    // What a document's variables start a run holding. Settled the way a
    // constant is, from what a constant settles from, reading those beside it
    // and no variable; the starting value is a fact the link reads, and a
    // variable's type is the type of that value.
    func variables(
        of module: Module,
        at origin: Int,
        beside known: [Name: Value],
        folding answered: Answered,
        writing lowering: inout Lowering,
        leaning fulfillment: Fulfillment,
        in context: TypingContext
    ) async throws -> [Name: Value] {
        guard !module.variables.isEmpty else { return [:] }

        var started: [Name: Value] = [:]

        for (name, expression) in module.variables.sorted { $0.key < $1.key } {
            let place = Place.variable(name.spelling, in: .of(module))

            try await fulfillment.folding(place) {
                let (judged, calls) = try await resolvedSites(
                    in: expression,
                    at: place,
                    in: known.mapValues { value in .fixed(type(of: value, in: context.loweredTypes)) },
                    with: context,
                    folding: nil,
                    writing: fulfillment
                )

                try checked(calls, in: context, writing: fulfillment)

                // A variable's starting value settles at the build the way a
                // constant's does, so it passes the same gate.
                try settles(judged, at: place, given: context, writing: fulfillment)

                do {
                    started[name] = try await Folding(
                        constants: known,
                        origin: origin,
                        in: answered,
                        loweredTypes: context.loweredTypes
                    ).read(judged, as: name, writing: &lowering, at: place)
                } catch let refused as BuildError {
                    throw refused
                } catch {
                    throw BuildError("\(error)", at: place)
                }
            }
        }

        return started
    }

    // The order a module's constants settle in: what a constant reads comes
    // before it. Constants that wait on each other have no such order, and that
    // is refused here, standing on one of them.
    // MARK: - Private
    private func order(
        _ constants: [Name: Expression],
        in module: Module
    ) throws -> [(name: Name, expression: Expression)] {

        var ordered: [(name: Name, expression: Expression)] = []
        var settled: Set<Name> = []

        // What the walk is standing on, root first. Where it meets a name
        // already on it, everything from that name down is the cycle, and
        // nothing above it is, which is the difference between what names
        // itself back and what merely waits on something that does.
        var walking: [Name] = []

        func place(_ name: Name, reading expression: Expression) throws {
            guard !settled.contains(name) else { return }

            if let met = walking.firstIndex(of: name) {
                let cycle = walking[met...].sorted()

                throw BuildError(
                    "constants \(cycle.map(\.spelling).joined(separator: ", ")) name each other in a"
                        + " cycle. A constant may name another declared beside it, but"
                        + " not one that names it back",
                    // Any of them is where the fix can be made, so the one
                    // walked to is the first in sorted order: a cycle has no
                    // first member, and reading one off the walk would name a
                    // different constant depending on where the walk started.
                    at: .constant(cycle[0].spelling, in: .of(module))
                )
            }

            walking.append(name)

            // Sorted, so a module with two mistakes in it refuses the same one
            // every run. What a set hands back is seeded per process.
            for read in mentions(of: expression).sorted() {
                // The walk goes only to names this module declared as constants.
                guard let reading = constants[read] else { continue }

                try place(read, reading: reading)
            }

            walking.removeLast()
            settled.insert(name)
            ordered.append((name, expression))
        }

        for (name, expression) in constants.sorted(by: { one, other in one.key < other.key }) {
            try place(name, reading: expression)
        }

        return ordered
    }

    // Every constant this expression names, at whatever depth.
    //
    // Flat, because nothing in here can mean anything but a constant: a body
    // may not introduce a name the module bound, which is settled where a
    // module is made, so no scope between a mention and this one can have taken
    // the spelling. A closure's body is walked with the rest. Making one
    // captures the scope it was written in, so a sibling it reads has to be
    // settled by then.
    private func mentions(of expression: Expression) -> Set<Name> {
        expression.subexpressions.reduce(into: Set<Name>()) { names, held in
            guard case let .reference(path) = held else { return }

            names.formUnion(path.expandingIndexReferences.compactMap(\.head))
        }
    }
}
