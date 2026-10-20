//
//  Compiler.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// One document compiled: its declarations judged against what they say and
// lowered, and its constants and variables settled, against what stands
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
    // What the document proves is written into `compiling`.
    func compile(
        _ module: Module,
        at origin: Int,
        declaring holding: [Symbol],
        against dependencies: [Fingerprint]?,
        as token: Compiled.Token,
        in compiling: inout Compiling
    ) async throws -> Compiled {
        let loweredTypes = compiling.loweredTypes

        // What this document declares and what its variables are called, in
        // the order the rows and the boxes stand in.
        let declared = holding.map(\.declared)
        let boxes = module.variables.keys.sorted()

        // What this document settled.
        var constants: [Name: Value] = [:]
        var variables: [Name: (value: Value, type: LoweredType)] = [:]

        // The variables that declared their type, by that type: a slot every
        // body of the document reads, which a call of the value one holds
        // leans on, and what each start settles into.
        let declaredVariables = declaredTypes(of: module, in: loweredTypes)

        // The constants with what each reads as, which seeds the environment
        // a body is judged in.
        var typedConstants: [Name: (value: Value, type: LoweredType)] = [:]

        // What each constant's value was written as where it was made. A
        // constant is a fixed name, so a call of the value it holds leans on
        // that as on any fixed name's.
        var declaredConstants: [Name: LoweredType] = [:]

        func context() -> TypingContext {
            compiling.context(of: origin)
        }

        // This document's declarations by the rows they stand at: what it
        // declares is its own whoever else may name it.
        func row(of symbol: Symbol) throws -> Int {
            guard let row = compiling.lowering.own(origin)[symbol.declared] else {
                throw BuildError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        // What this document declares, by the spelling a call in it writes.
        // Its own rows do not stand yet, and this is what says what they take
        // until they do.
        let own = holding.reduce(into: [Name: Signature]()) { asked, symbol in
            asked[symbol.declared] = symbol.procedure.signature
        }

        // What the documents behind this one declare, read the way a body in
        // this one reads them.
        let behind = compiling.context()

        // The names in scope before a body's first statement: the constants
        // and the variables its module declared, and its parameters, a
        // parameter standing for the name it spells. A module variable holds
        // the type it declared, or the type it started as, through every
        // write, because every body of the document reads it as that.
        func opening(_ signature: Signature) -> [Name: Binding] {
            bindings(of: typedConstants, declaring: declaredConstants)
                .merging(
                    variables.reduce(into: [Name: Binding]()) { held, entry in
                        held[entry.key] = Binding(
                            declaredVariables[entry.key].map(Binding.Holding.declared) ?? .held(entry.value.type),
                            entry.value.type,
                            declarer: .module
                        )
                    }
                ) { _, variable in variable }
                .merging(signature.environment(in: loweredTypes)) { _, parameter in parameter }
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
                    with: context().reading(declaration.signature),
                    folding: folding
                )

                // What the body does is held to what its declaration says,
                // every callee read by its own declaration, so a body is
                // judged alone.
                if let refusal = EffectChecker(context()).refusal(
                    of: block,
                    declared: declaration.signature,
                    in: opening(declaration.signature)
                ) {
                    throw BuildError("'\(symbol.declared)' \(refusal)", at: symbol.place)
                }

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

            // Judged as the declaration reads its own type parameters, since an
            // associated type a call fills from one is the declaration's.
            try TypeChecker().checked(answer.calls, in: context().reading(answer.procedure.signature))

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                try compiling.lower(try row(of: symbol), body: rewritten, judgements: answer.judgements, at: symbol.place)
            }

            return answer.procedure
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
            taking: { selector in own[selector] ?? behind.declared(selector)?.signature },
            contractProcedures: Set(behind.contractProcedures.keys),
            concealing: behind.concealed
        )

        // The rows this document's declarations stand at, in name order. What a
        // document declares is a run of rows rather than declarations
        // scattered through the table, so where its rows begin is a number
        // and its own are that number and an offset. A native answers as
        // it is from the start; a written body stands as the refusal it
        // would earn until it is lowered, so nothing folds through a body
        // half-made.
        let (heldAt, standing) = compiling.lowering.hold(
            standing: try holding.map { symbol in
                Linked.unlowered(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    builtin: module.builtin,
                    sends: try sending.rows(of: symbol),
                    in: loweredTypes
                )
            },
            numbering: numbering,
            variables: boxes
        )

        assert(heldAt == origin, "a document is compiled at the origin it is held at")

        compiling.lowering.resolve(origin)

        // The bodies the documents behind this one lowered, which this one
        // may run.
        compiling.foldable()

        // Read once the document's rows stand, since a constant's value may be
        // what one of them answers, and in the order constants settle, since
        // one may read another through a path.
        let effects = EffectChecker(context())

        declaredConstants = order(module.constants).reduce(into: [Name: LoweredType]()) { declared, constant in
            let before = declared

            declared[constant.name] = effects.declaredType(
                of: .constant(constant.name),
                reading: constant.expression,
                given: { read in before[read] }
            )
        }

        // Settled after the procedures are known, because a constant may call
        // one: a constant that spells a URL out of other constants spells it
        // with procedures like any other expression.
        //
        // The context is read before the lowering is handed over, since one of
        // the tables a context stands on is the lowering this writes into.
        typedConstants = try await self.constants(
            of: module,
            at: origin,
            declaring: declaredConstants,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            in: context()
        )

        constants = typedConstants.mapValues(\.value)
        compiling.lowering.settle(constants: constants, of: origin)

        variables = try await self.variables(
            of: module,
            at: origin,
            declaring: declaredVariables,
            beside: typedConstants,
            declaredAs: declaredConstants,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            in: context()
        )

        // Every declaration this document makes, in name order, which is
        // the order its rows stand in. What a document says has to hold
        // whether or not a run walks that way, so which declarations are
        // judged is not a question any run answers.
        for symbol in holding {
            _ = try await resolved(symbol)
        }

        // The types its bodies stand on, written as this document's own
        // numbers.
        // Lowering read the link's table to judge, so what it wrote is that
        // link's rows; what leaves here is the document's.
        //
        // Its rows are its declarations in name order, then the closures its
        // bodies lifted, in the order it numbers them.
        let lowered = try compiling.lowering.numbered(
            Array(standing) + compiling.lowering.documents[origin].closureRows
        )

        return Compiled(
            document: .of(module),
            types: module.types,
            contracts: module.contracts,
            claims: module.claims,
            members: module.members,
            typeMembers: module.typeMembers,
            importedClaims: module.importedClaims,
            declared: declared,
            constants: module.constants.keys.sorted(),
            table: lowered.table.map(Judged.init),
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
        declaring declaredTypes: [Name: LoweredType],
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
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

            let (value, written) = try await settled(
                expression,
                as: name,
                into: nil,
                at: place,
                beside: known,
                declaredAs: declaredTypes,
                of: origin,
                folding: resolved,
                writing: &lowering,
                in: context
            )

            known[name] = (
                value,
                LoweredType(of: value, in: context.loweredTypes).refined(by: written.folded)
            )
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
        declaredAs declaredConstants: [Name: LoweredType],
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
        in context: TypingContext
    ) async throws -> [Name: (value: Value, type: LoweredType)] {
        guard !module.variables.isEmpty else { return [:] }

        var started: [Name: (value: Value, type: LoweredType)] = [:]

        for (name, variable) in module.variables.sorted(by: { $0.key < $1.key }) {
            let place = Place.variable(name.spelling, in: .of(module))

            // A start written as a literal is read as what the variable
            // declares.
            let declaredType = declaredTypes[name]
            let start = declaredType.map { declaredType in
                declaredType.written(variable.start, in: context.loweredTypes)
            } ?? variable.start

            let (settled, written) = try await self.settled(
                start,
                as: name,
                into: declaredType,
                at: place,
                beside: known,
                declaredAs: declaredConstants,
                of: origin,
                folding: resolved,
                writing: &lowering,
                in: context
            )

            // A variable holds what it declares, which the start was held
            // to as it was read, or else what the start reads. An empty
            // list or map holds no element, so a start of one says
            // nothing of what the box will hold.
            let holding = declaredType ?? written.folded.boxed

            guard declaredType != nil || !holding.holdsNoElement else {
                throw BuildError(
                    "starts as \(holding.rendered(in: context.loweredTypes)), which holds nothing,"
                        + " and declares no type, so nothing says what it holds."
                        + " A variable starting empty declares its type or casts its start",
                    at: place
                )
            }

            started[name] = (settled, holding)
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
    // rather than run, so it passes the gate an operand does. A struct
    // literal in it is read as the declared struct of the place it is
    // written into.
    private func settled(
        _ expression: Expression,
        as name: Name,
        into declared: LoweredType?,
        at place: Place,
        beside known: [Name: (value: Value, type: LoweredType)],
        declaredAs declaredConstants: [Name: LoweredType],
        of origin: Int,
        folding resolved: ResolvedTable,
        writing lowering: inout Lowering,
        in context: TypingContext
    ) async throws -> (value: Value, written: LiteralShape) {
        let environment = bindings(of: known, declaring: declaredConstants)
        let (judged, calls, judgements, written) = try await TypeChecker().resolvedSites(
            in: expression,
            into: declared,
            at: place,
            in: environment,
            with: context,
            folding: nil
        )

        try TypeChecker().checked(calls, in: context)
        try TypeChecker().refuseRunning(in: judged, at: place, bound: environment, given: context)

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

    // The constants settled so far as names a body or a later constant
    // reads, each holding the type written where its value came from.
    private func bindings(
        of constants: [Name: (value: Value, type: LoweredType)],
        declaring declaredTypes: [Name: LoweredType]
    ) -> [Name: Binding] {
        constants.reduce(into: [Name: Binding]()) { held, entry in
            held[entry.key] = Binding(.fixed(declared: declaredTypes[entry.key]), entry.value.type, declarer: .module)
        }
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
            for read in expression.freeNames.sorted() {
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
