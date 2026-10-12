//
//  Compiler.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// One document compiled: its declarations judged and lowered, its facts
// derived, and its constants and variables settled, against what stands
// before it.
struct Compiler {
    // MARK: - Property
    // The declarations a fold of this document may run where it calls
    // through a contract: those of every document it stands on, near or far,
    // and its own. A claim another document makes is a fact of the whole
    // list, and what this document settles at the build stands on what it
    // names alone, so which documents the host handed over beside it changes
    // nothing it settles.
    private let witnesses: Set<Name>

    // MARK: - Initializer
    init(foldingThrough witnesses: Set<Name>) {
        self.witnesses = witnesses
    }

    // MARK: - Public
    // What the document proves is written into `compiling`. Its own rows stand
    // as the refusal they would earn until it lowers them, so a procedure
    // folding through a procedure is refused as the cycle it is.
    func compile(
        _ module: Module,
        at origin: Int,
        declaring holding: [Symbol],
        leaning dependencies: [Fingerprint]?,
        as token: Compiled.Token,
        in compiling: inout Compiling,
        writing fulfillment: Fulfillment
    ) async throws -> Compiled {
        fulfillment.laying(origin, at: Place(in: .of(module)))

        let loweredTypes = compiling.loweredTypes

        // What this document declares and what its variables are called, in
        // the order the rows and the boxes stand in.
        let declared = holding.map(\.declared)
        let boxes = module.variables.keys.sorted()
        let reading = Set(module.variables.keys)

        // What the build read off this document's bodies whose declarations
        // wrote no `returns`.
        var read: [Name: LoweredType] = [:]

        // What this document settled.
        var constants: [Name: Value] = [:]
        var variables: [Name: (value: Value, type: LoweredType)] = [:]

        // The variables that declared their type, by that type: a slot every
        // body of the document reads, which a call of the value one holds
        // leans on, and what each start settles into.
        let declaredVariables = declaredTypes(of: module, in: loweredTypes)

        // The constants with what each reads as: what seeds the environment a
        // body is judged in, and what a body binds where it reads one at an
        // index the run reads.
        var typedConstants: [Name: (value: Value, type: LoweredType)] = [:]

        func context() -> TypingContext {
            compiling.context(reading: reading, of: origin)
        }

        // This document's declarations by its block: what it declares is its
        // own whoever else may name it.
        func row(of symbol: Symbol) throws -> Int {
            guard let row = compiling.lowering.own(origin)[symbol.declared] else {
                throw BuildError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        // The names in scope before a body's first statement: its parameters,
        // the constants its module declared beside them, and the variables. A
        // module variable holds the type it declared, or the type it started
        // as, through every write, because every body of the document reads
        // it as that.
        func opening(_ signature: Signature) -> [Name: Binding] {
            signature.environment(in: loweredTypes)
                .merging(typedConstants.mapValues { constant in Binding(.fixed(declared: nil), constant.type) }) { _, constant in
                    constant
                }
                .merging(
                    variables.reduce(into: [Name: Binding]()) { held, entry in
                        held[entry.key] = Binding(
                            declaredVariables[entry.key].map(Binding.Holding.declared) ?? .held(entry.value.type),
                            entry.value.type
                        )
                    }
                ) { _, variable in variable }
        }

        // One declaration resolves once, whichever table asks.
        var resolvedBodies: [Name: Procedure] = [:]

        // A declaration, bound and dot-judged: every dot in the body is judged
        // against the type it reaches, every call is gathered, a
        // constant-headed path (judged first, like any path) folds to the
        // value it is, and a closure literal's signature is bounded by the
        // declaration's. The image holds only this form.
        //
        // Every call the body writes is checked here too, reached or not:
        // callee declared, arguments taken.
        func resolved(_ symbol: Symbol) async throws -> Procedure {
            if let done = resolvedBodies[symbol.declared] { return done }

            let declaration = symbol.procedure

            var answer = (procedure: declaration, calls: [CallSite](), judgements: JudgementTable())

            if let block = declaration.block {
                // A body not yet lowered stands as its refusal, so a procedure
                // folding through a procedure is refused as the cycle it is.
                let folding = Folding(
                    constants: constants,
                    origin: origin,
                    in: compiling.folding(),
                    answering: context().contractProcedures,
                    through: witnesses,
                    loweredTypes: loweredTypes
                )

                // The starting environment knows the constants beside the
                // parameters, so a constant-headed path is judged against the
                // type of the value it will fold to.
                let (rewritten, gathered, judgements) = try await TypeChecker().resolvedSites(
                    in: block,
                    at: symbol.place,
                    in: opening(declaration.signature),
                    declaring: symbol.declared,
                    answering: declaration.signature.returns,
                    with: context().bounding(declaration.signature.bounds),
                    folding: folding,
                    writing: fulfillment
                )

                answer = (
                    procedure: Procedure(
                        description: declaration.description,
                        signature: declaration.signature,
                        implementation: .body(rewritten)
                    ),
                    calls: gathered,
                    judgements: judgements
                )
            }

            resolvedBodies[symbol.declared] = answer.procedure

            try TypeChecker().checked(answer.calls, in: context(), writing: fulfillment)

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                try compiling.lower(try row(of: symbol), body: rewritten, judgements: answer.judgements, at: symbol.place)
            }

            return answer.procedure
        }

        // The facts nobody declared. All three are fixed points over what a
        // body reaches, so a document's answer is decided once the documents
        // it reaches have theirs, and the standing refused a cycle where that
        // is not so. Read over every declaration the document holds.
        //
        // What this document declares, by the spelling a call in it writes.
        // Its own rows do not stand yet, and this is what says what they take
        // until they do.
        let own = holding.reduce(into: [Name: Signature]()) { asked, symbol in
            asked[symbol.declared] = symbol.procedure.signature
        }

        // What the documents behind this one declare, read the way a body in
        // this one reads them.
        let behind = compiling.context(reading: reading)

        // What a selector this document may reach takes: its own declarations
        // first, the documents standing before it after. One rule, so the two
        // judgements standing on it read the same declaration.
        let taking: @Sendable (Name) -> Signature? = { selector in
            own[selector] ?? behind.signature(of: selector)
        }

        // Derived over this document's declarations, and read off the rows
        // for every other: what the build derives of a declaration stands on
        // its row, so a document's own facts are its own until its rows stand.
        var const: Set<Name> = []
        var isolated: Set<Name> = []
        var failing: [Name: Failing] = [:]
        let answersWithoutRunning: @Sendable (Name) -> Bool = { selector in behind.isConst(selector) }
        let touchesNothingShared: @Sendable (Name) -> Bool = { selector in behind.isIsolated(selector) }

        Derivation().const(
            among: holding,
            deriving: &const,
            reading: reading,
            beside: declaredVariables,
            taking: taking,
            beyond: answersWithoutRunning,
            in: loweredTypes
        )
        Derivation().isolated(
            among: holding,
            deriving: &isolated,
            beside: declaredVariables,
            taking: taking,
            beyond: touchesNothingShared,
            in: loweredTypes
        )
        Derivation().failing(among: holding, deriving: &failing) { selector in behind.failing(of: selector) }

        let ownNames = Set(holding.map(\.declared))
        let constant: @Sendable (Name) -> Bool = { [const] selector in
            ownNames.contains(selector) ? const.contains(selector) : answersWithoutRunning(selector)
        }
        let untouched: @Sendable (Name) -> Bool = { [isolated] selector in
            ownNames.contains(selector) ? isolated.contains(selector) : touchesNothingShared(selector)
        }

        // Where this document numbers its calls from: what it looks for
        // outside itself first, its own declarations after. Built from the
        // document alone, so a body lowers to the same numbers whatever
        // else the host put in the link.
        let numbering = Numbering(
            sends: module.sends,
            declared: declared,
            closures: module.closures
        )
        let sending = Sending(
            numbering: numbering,
            const: constant,
            isolated: untouched,
            taking: { selector in own[selector] ?? behind.declared(selector)?.signature },
            contractProcedures: Set(behind.contractProcedures.keys),
            concealing: behind.concealed
        )

        // This document's block of the table, in name order. What a
        // document declares is a run of rows rather than declarations
        // scattered through the table, so where its rows begin is a number
        // and its own are that number and an offset. A native answers as
        // it is from the start; a written body stands as the refusal it
        // would earn until it is lowered, so nothing folds through a body
        // half-made.
        let (heldAt, block) = compiling.lowering.hold(
            standing: try holding.map { symbol in
                Linked.unlowered(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    const: const.contains(symbol.declared),
                    isolated: isolated.contains(symbol.declared),
                    failing: failing[symbol.declared] ?? .unstated,
                    builtin: module.builtin,
                    sends: try sending.rows(of: symbol),
                    in: loweredTypes
                )
            },
            numbering: numbering,
            variables: boxes,
            declaring: declaredVariables
        )

        assert(heldAt == origin, "a document is compiled at the origin it is held at")

        compiling.lowering.resolve(origin)

        // The bodies the documents behind this one lowered, which this one
        // may run.
        compiling.foldable()

        // Settled after the procedures are known, because a constant may call
        // one: a constant that spells a URL out of other constants spells it
        // with procedures like any other expression.
        //
        // The context is read before the lowering is handed over, since one of
        // the tables a context stands on is the lowering this writes into.
        typedConstants = try await self.constants(
            of: module,
            at: origin,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            leaning: fulfillment,
            in: context()
        )

        constants = typedConstants.mapValues(\.value)
        compiling.lowering.settle(constants: typedConstants, of: origin)

        variables = try await self.variables(
            of: module,
            at: origin,
            declaring: declaredVariables,
            beside: typedConstants,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            leaning: fulfillment,
            in: context()
        )

        // What every declaration of this document whose `returns` nobody
        // wrote answers, read off its body.
        await TypeChecker().answers(
            of: holding.compactMap { symbol -> TypeChecker.Unsaid? in
                guard
                    symbol.procedure.signature.returns == nil,
                    let block = symbol.procedure.block
                else { return nil }

                return TypeChecker.Unsaid(
                    symbol: symbol,
                    block: block,
                    environment: opening(symbol.procedure.signature),
                    sends: TypeChecker().sent(in: block)
                )
            },
            reading: context,
            recording: { qualified, answer in
                read[qualified] = answer

                compiling.read(answer, as: qualified, of: origin)
            }
        )

        // Every declaration this document makes, in name order, which is
        // the order its rows stand in. What a document says has to hold
        // whether or not a run walks that way, so which declarations are
        // judged is not a question any run answers.
        for symbol in holding {
            try await fulfillment.folding(symbol.place) {
                _ = try await resolved(symbol)
            }
        }

        // The types its bodies and the answers read off them stand on,
        // written as this document's own numbers. Lowering read the link's
        // table to judge, so what it wrote is that link's rows; what leaves
        // here is the document's.
        //
        // Its rows are its declarations in name order, then the closures its
        // bodies lifted, in the order it numbers them.
        let lowered = try compiling.lowering.numbered(
            Array(block) + compiling.lowering.documents[origin].closureRows,
            answering: read
        )

        return Compiled(
            document: .of(module),
            types: module.types,
            contracts: module.contracts,
            claims: module.claims,
            leaned: fulfillment.claims(of: origin),
            declared: declared,
            constants: module.constants.keys.sorted(),
            table: lowered.table.map(Judged.init),
            answers: lowered.answers,
            numbering: numbering,
            typeNumbering: lowered.numbering,
            variables: boxes.map { name in (name: name, value: variables[name]?.value ?? .null) },
            dependencies: dependencies,
            token: token
        )
    }

    // MARK: - Private
    // A document's constants, settled, each beside what it reads as. They are
    // evaluated here because there is nothing about them left for a run to do:
    // a constant sees no scope, so what it will be is knowable the moment the
    // document is read.
    //
    // One may name another declared beside it, so they are settled in the order
    // they read each other, and that order is worked out first.
    private func constants(
        of module: Module,
        at origin: Int,
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
        leaning fulfillment: Fulfillment,
        in context: TypingContext
    ) async throws -> [Name: (value: Value, type: LoweredType)] {
        // Folding runs what it reads, and running reads rows. A lowered body
        // carries its document's own numbers, so the table handed here is one
        // that says which row each of those numbers stands for.
        //
        // The context is the document's own, since a document reads its own
        // constants, and it is handed over rather than asked for: the lowering
        // this writes into is one of the tables a context is read off.
        guard !module.constants.isEmpty else { return [:] }

        var known: [Name: (value: Value, type: LoweredType)] = [:]

        // Handed over with what each one reads, so nothing looks a name
        // back up in the table the order was read from. Everything this one
        // needs comes before it, and asking again is a second chance to ask
        // a different table.
        for (name, expression) in order(module.constants) {
            let place = Place.constant(name.spelling, in: .of(module))

            try await fulfillment.folding(place) {
                let (value, written) = try await settled(
                    expression,
                    as: name,
                    into: nil,
                    at: place,
                    beside: known,
                    of: origin,
                    folding: resolved,
                    writing: &lowering,
                    leaning: fulfillment,
                    in: context
                )

                known[name] = (
                    value,
                    LoweredType(of: value, in: context.loweredTypes).refined(by: written.folded)
                )
            }
        }

        return known
    }

    // What a document's variables start a run holding. Settled the way a
    // constant is, from what a constant settles from, reading those beside it
    // and no variable; the starting value is a fact the link reads. A variable
    // that declares what it holds has its start held to that at the build,
    // the way an argument is held to its slot, and holds that type; one that
    // declares nothing holds the type its start reads as.
    private func variables(
        of module: Module,
        at origin: Int,
        declaring declaredTypes: [Name: LoweredType],
        beside known: [Name: (value: Value, type: LoweredType)],
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
        leaning fulfillment: Fulfillment,
        in context: TypingContext
    ) async throws -> [Name: (value: Value, type: LoweredType)] {
        guard !module.variables.isEmpty else { return [:] }

        var started: [Name: (value: Value, type: LoweredType)] = [:]

        for (name, variable) in module.variables.sorted(by: { $0.key < $1.key }) {
            let place = Place.variable(name.spelling, in: .of(module))

            // A start written as a literal, or as a closure literal that
            // writes no answer, is read as what the variable declares.
            let declaredType = declaredTypes[name]
            let start = declaredType.map { declaredType in
                declaredType.written(
                    declaredType.completing(variable.start, in: context.loweredTypes),
                    in: context.loweredTypes
                )
            } ?? variable.start

            try await fulfillment.folding(place) {
                let (settled, written) = try await self.settled(
                    start,
                    as: name,
                    into: declaredType,
                    at: place,
                    beside: known,
                    of: origin,
                    folding: resolved,
                    writing: &lowering,
                    leaning: fulfillment,
                    in: context
                )

                guard let declared = variable.declared, let holding = declaredType else {
                    let holding = written.folded.boxed

                    // An empty list or map holds no element, so a start of
                    // one says nothing of what the box will hold.
                    guard !holding.holdsNoElement else {
                        throw BuildError(
                            "starts as \(holding.rendered(in: context.loweredTypes)), which holds nothing,"
                                + " and declares no type, so nothing says what it holds."
                                + " A variable starting empty declares its type or casts its start",
                            at: place
                        )
                    }

                    started[name] = (settled, holding)
                    return
                }

                // What the start reads is held to what the variable declares,
                // the way a name's value is.
                guard written.isHeld(by: holding, inPlace: false, in: context.loweredTypes) else {
                    throw BuildError(
                        "starts as \(written.rendered(in: context.loweredTypes)), and declares \(declared)",
                        at: place
                    )
                }

                do {
                    started[name] = (
                        try holding.settling(settled, at: "the start of '\(name)'", in: context.loweredTypes),
                        holding
                    )
                } catch {
                    throw BuildError("starts outside \(declared), which it declares: \(error)", at: place)
                }
            }
        }

        return started
    }

    // What a constant or a variable's start settles to, beside the shape it
    // was written as and what it was judged to read. Its dots are judged
    // before it settles, the way a body's are: the settled constants' types
    // are the environment, so an absent field or a needless `?.` refuses here
    // by the one rule, and carries its own place. A closure it holds runs
    // later, so settling proves nothing about the sends inside it, and they
    // pass the gate every gathered call does. What it is written from is read
    // rather than run, so it passes the gate an operand does. A record
    // literal in it is read as the declared record of the place it is
    // written into.
    private func settled(
        _ expression: Expression,
        as name: Name,
        into declared: LoweredType?,
        at place: Place,
        beside known: [Name: (value: Value, type: LoweredType)],
        of origin: Int,
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
        leaning fulfillment: Fulfillment,
        in context: TypingContext
    ) async throws -> (value: Value, written: LiteralShape) {
        let (judged, calls, judgements, written) = try await TypeChecker().resolvedSites(
            in: expression,
            into: declared,
            at: place,
            in: known.mapValues { constant in Binding(.fixed(declared: nil), constant.type) },
            with: context,
            folding: nil,
            writing: fulfillment
        )

        try TypeChecker().checked(calls, in: context, writing: fulfillment)
        try TypeChecker().refuseRunning(in: judged, at: place, given: context, writing: fulfillment)

        do {
            let value = try await Folding(
                constants: known.mapValues(\.value),
                origin: origin,
                in: resolved,
                answering: context.contractProcedures,
                through: witnesses,
                loweredTypes: context.loweredTypes
            ).read(judged, as: .binding(name), judgements: judgements, writing: &lowering, at: place)

            return (value, written)
        } catch let refused as BuildError {
            throw refused
        } catch {
            throw BuildError("\(error)", at: place)
        }
    }

    // The types a document's variables declare, lowered once.
    private func declaredTypes(of module: Module, in table: LoweredTypeTable) -> [Name: LoweredType] {
        module.variables.compactMapValues { variable in variable.declared?.lowered(in: table) }
    }

    // The order a module's constants settle in: what a constant reads comes
    // before it. The load holds a module's constants to naming no cycle.
    private func order(_ constants: [Name: Expression]) -> [(name: Name, expression: Expression)] {
        var ordered: [(name: Name, expression: Expression)] = []
        var placed: Set<Name> = []

        func place(_ name: Name, reading expression: Expression) {
            guard placed.insert(name).inserted else { return }

            // Sorted, so the order is the same every run. What a set hands
            // back is seeded per process.
            for read in expression.pathHeads.sorted() {
                // The walk goes only to names this module declared as constants.
                guard let reading = constants[read] else { continue }

                place(read, reading: reading)
            }

            ordered.append((name, expression))
        }

        for (name, expression) in constants.sorted(by: { one, other in one.key < other.key }) {
            place(name, reading: expression)
        }

        return ordered
    }
}
