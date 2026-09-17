//
//  Builder.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this run was given and one name to start from, and answers
// with an image, or refuses.
//
// A build is handed its whole module graph at once. The procedures a program can
// call are the procedures the caller put in front of it, so what to build is the
// caller's statement and joining the names up is this. A module's `imports` says what it
// asks for and never where to find it, and the entry is an argument rather than
// a name written into a document.
//
// Every declaration is judged, not the reached ones. A misspelled procedure in
// an arm today's arguments never take is a defect whether or not this run walks
// that way, and so is one in a declaration this entry never calls. The entry
// says which declarations a run reaches and nothing about which ones hold.
//
// Every call goes through the same gate: a procedure the host installed and one
// another document wrote are checked against a signature by the same code, and
// the only difference is where the signature came from. The installed table, or
// another module in the same link.
//
// A name is its declared spelling and nothing else. A call site says
// `std.math.plus`, and that is the one declaration it can mean, wherever it was
// written; the image the executor runs is spelled the way the documents were,
// so a run never has to ask again. Constants do change here: a name bound to a
// value at load has nothing left to do at run time, so compiling folds it into
// the literal it always was.
//
// What it can promise is narrower than "nothing unresolved remains": arguments
// are mostly references that settle at run time, so this checks names, arity and
// the types of *constant* arguments. Calling a value is outside the promise
// entirely, because a closure's callee is a run-time fact.
//
// Two stages, and the entry names nothing in the first. Compiling settles
// everything a document says against the interfaces it reaches: resolving
// (`Builder+Resolving`), the facts nobody declared (`Builder+Deriving`,
// `Builder+Isolating`), judging (`Builder+Judging`, `Builder+Typing`) and
// lowering (`Lowering`). It runs the procedures a constant calls, which is what
// folding is. Linking takes what that answered and one name to start from,
// judges what only the whole list can answer, and runs nothing.
public struct Builder: Sendable {
    // MARK: - Property
    // How an object's fingerprint is worked out, where a caller wants its
    // objects to say what they are true against.
    //
    // Taken rather than done here. A fingerprint is about bytes, and what
    // writes bytes is another package: this one is the language and does not
    // know how a value is laid down. A caller that never files an object
    // hands nothing over and is handed objects that say they cannot be
    // filed, which is what they are.
    private let fingerprinting: (@Sendable (Value) throws -> Fingerprint)?

    // MARK: - Initializer
    public init(fingerprinting: (@Sendable (Value) throws -> Fingerprint)? = nil) {
        self.fingerprinting = fingerprinting
    }

    // MARK: - Public
    // Compiling and then linking, which is what building is.
    //
    // What to build is the caller's statement (the whole graph at once) and
    // `entry` names which declaration this run starts from. There is no
    // default: guessing which procedure was meant would be an opinion nobody
    // gave.
    //
    // A bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func build(_ modules: [Module], entry: Name) async throws -> Image {
        try await link(compile(modules), entry: entry, supplying: Supplying(modules))
    }

    // Documents compiled and handed back, for a caller that means to build
    // them more than once.
    //
    // A build does two things: it works out what each document says, and it
    // lays the documents down together. The first is a function of the
    // document and of what it reaches, so a caller holding the answer can hand
    // it over instead of asking for it again. The vocabulary a host brings is
    // the same documents every run, and this is how it stops paying for them
    // every run.
    //
    // The order is worked out here. What a document reaches is read off the
    // procedures it sends and the types its signatures name, neither of which a
    // caller wrote down, so a caller has nothing to sort by.
    //
    public func compile(_ modules: [Module]) async throws -> [Compiled] {
        try await compile(modules, against: [], supplying: .none)
    }

    // The same, against documents the caller already holds.
    //
    // `compiled` is what the caller already holds, and the documents given
    // here are compiled against it. A procedure a document sends is answered by
    // either, and one that nothing here answers is refused where it is sent.
    //
    // The objects and the code behind them are asked for together, since
    // neither is any use here without the other: an object names its
    // natives and holds none of the code, and folding a constant runs the
    // procedures the documents behind it declared.
    public func compile(
        _ modules: [Module],
        against compiled: [Compiled],
        supplying natives: Supplying
    ) async throws -> [Compiled] {
        try await compile(modules, against: try lay(compiled, supplying: natives))
    }

    // Documents already compiled, with the rows they stand as made once, so a
    // caller compiling against them more than once pays for that once.
    //
    // What it costs is every declaration behind the one being compiled: its
    // signature lowered into slots, and for a native the host's procedure joined to
    // it under its spelling. A host brings the same vocabulary every run, and
    // this is where it stops turning it into rows every time.
    public func lay(_ compiled: [Compiled], supplying natives: Supplying) throws -> Laid {
        guard !compiled.isEmpty else { return .none }

        let linkage = Linkage()
        let declared = try declared(in: compiled)
        let declaring = try types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: compiled,
            standing: Array(compiled.indices),
            numbered: linkage
        )

        let signatures = signatures(of: compiled)

        // Which types answer which contracts among these documents. A row
        // whose signature names a contract lowers against that reading, so it
        // is worked out here rather than left to the compile that asks.
        let lowered = try lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures
        )

        var compiling = Compiling(
            types: lowered.types,
            contractProcedures: lowered.contractProcedures,
            naming: compiled.map(\.document)
        )

        for (origin, document) in compiled.enumerated() {
            let numbered = document.typeNumbering.rows(in: lowered.types.loweredTypes)

            let rows = try document.table.map { judged -> Linked in
                let row = try judged.folding(
                    in: lowered.types.loweredTypes,
                    of: origin,
                    supplied: natives,
                    at: document.document
                )

                return try row.renumbered { type in
                    try numbered.read(type, at: .procedure(row.label.spelling, in: document.document))
                }
            }

            let answered = try document.answers.reduce(into: [Name: LoweredType]()) { read, answer in
                read[answer.key] = try numbered.read(
                    answer.value,
                    at: .procedure(answer.key.spelling, in: document.document)
                )
            }

            compiling.lay(document, at: origin, rows: rows, answering: answered)
        }

        try compiling.answering()

        return Laid(
            compiled: compiled,
            carried: compiling.carried,
            signatures: signatures,
            linkage: linkage
        )
    }

    // An object said as what it is, where the caller handed over how that is
    // worked out. One that cannot be written down has nothing to work it out
    // from, which is the same absence said one step earlier.
    private func fingerprinted(_ object: Compiled) throws -> Compiled {
        guard let fingerprinting, let written = object.written else { return object }

        return object.fingerprinted(try fingerprinting(written))
    }

    // Every declaration a compiled document made, under the spelling it was
    // declared by and at the place it was written. What a document declares is
    // its own; where it stands among the documents is the caller's order.
    private func signatures(of compiled: [Compiled]) -> [Name: Placed<Signature>] {
        var signatures: [Name: Placed<Signature>] = [:]

        for (position, document) in compiled.enumerated() {
            for (offset, name) in document.declared.enumerated() {
                signatures[name] = Placed(
                    document.table[offset].signature,
                    at: .procedure(name.spelling, in: document.document),
                    of: position
                )
            }
        }

        return signatures
    }

    // The same, against documents a caller already laid down.
    public func compile(_ modules: [Module], against laid: Laid) async throws -> [Compiled] {
        let compiled = laid.compiled

        try once(modules, against: compiled)

        // Every name held to one declarer before the standing is read.
        // Standing reads a name as whichever document declared it, and where
        // two declare one name that reading is arbitrary: it can put a
        // document in its own reach and call the pair a ring. The doubled name
        // is the defect, so it is the refusal an author gets.
        let held = try symbols(of: modules, after: compiled.count)
        let declared = try declared(in: compiled + modules)
        let standing = try ModuleGraph(modules, after: compiled.count).standing
        let lowered = try await compile(
            modules,
            at: standing,
            declaring: held,
            over: declared,
            against: laid
        )

        // Back in the order the documents were handed over. A document says
        // nothing about where it stands, so the order a link reads them in is
        // the caller's.
        var ordered = lowered

        for (position, origin) in standing.enumerated() {
            ordered[origin] = lowered[position]
        }

        return ordered
    }

    // Documents laid down one at a time, in the order `standing` gives, each
    // against the ones already compiled and the ones laid before it.
    //
    // What only the whole list answers is read once, here: the type tables of
    // a link are its documents' together, and documents handed over already
    // compiled were not in the ones the others were compiled against.
    //
    // The ledger is the compile's rather than each document's. A fold runs
    // bodies of the documents behind it and what it turns up belongs to the
    // one being laid down, which is what the ledger is told.
    func compile(
        _ modules: [Module],
        at standing: [Int],
        declaring symbols: [Symbol],
        over declared: (
            types: [Name: Placed<TypeExpression>],
            constraints: [Name: Placed<[TypeExpression]>],
            contracts: [Name: Placed<[Name: Signature]>],
            claims: [Placed<Claim>]
        ),
        against laid: Laid
    ) async throws -> [Compiled] {
        let compiled = laid.compiled
        let laying = standing.map { position in modules[position] }
        let documents: [any Declaring] = compiled + laying

        let declaring = try types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: documents,
            standing: Array(documents.indices),
            numbered: laid.linkage
        )

        try judge(laying, in: declaring)

        // Every declaration these documents are compiled beside, by the
        // spelling it was declared by: what the documents behind them left on
        // their rows, and what they wrote themselves. A name two of them
        // declare is refused here, for the same reason two `.c` files cannot
        // both define a symbol.
        //
        // Refused rather than taken as the caller's statement, which the order
        // is: a doubled spelling is not a question of which document to read
        // first, it is a table with no answer for that name.
        var signatures = laid.signatures

        // The declarations of each document laid down, under the row it will
        // take here. What a document declares is its own; where the rows stand
        // is this compile's.
        let written = symbols.reduce(into: [Int: [Symbol]]()) { held, symbol in
            held[symbol.origin, default: []].append(symbol)
        }
        let holding = standing.enumerated().map { offset, position in
            (written[position] ?? []).map { symbol in
                Symbol(
                    declared: symbol.declared,
                    document: symbol.document,
                    origin: compiled.count + offset,
                    handed: symbol.handed,
                    procedure: symbol.procedure
                )
            }
        }

        for symbols in holding {
            for symbol in symbols {
                if let first = signatures[symbol.declared] {
                    throw BuildError(
                        "'\(symbol.declared)' is declared by \(first.spelled) and by"
                            + " \(symbol.spelled). Two declarations of a name have no way"
                            + " to be told apart",
                        at: symbol.place
                    )
                }

                signatures[symbol.declared] = Placed(
                    symbol.procedure.signature,
                    at: symbol.place,
                    of: symbol.handed
                )
            }
        }

        // The compile's ledger, woven into the table its rows are built from.
        // A body folded here runs against a table that cannot settle a
        // contract, and what it hands over is written here rather than passed
        // over.
        let fulfillment = Fulfillment()
        let lowered = try self.lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures,
            unsettled: fulfillment
        )

        var compiling = Compiling(
            laid.carried,
            types: lowered.types,
            contractProcedures: lowered.contractProcedures,
            naming: documents.map(\.document)
        )

        // What each document turned out to be, as they are laid down. A
        // document laid here may be what the next one leans on, and what it
        // leaned on is part of what it is, so the two grow together.
        var declarers = DeclarerTable()

        for object in compiled {
            declarers.lay(object)
        }

        var built: [Compiled] = []

        for offset in laying.indices {
            let object = try await compile(
                laying[offset],
                at: compiled.count + offset,
                declaring: holding[offset],
                leaning: declarers.dependencies(of: laying[offset]),
                in: &compiling,
                writing: fulfillment
            )
            let known = try fingerprinted(object)

            declarers.lay(known)
            built.append(known)
        }

        return built
    }

    // One document compiled against what stands before it, and what it proves
    // written into that. Its own rows stand as the refusal they would earn
    // until it lowers them, so a procedure folding through a procedure is refused as the
    // cycle it is.
    func compile(
        _ module: Module,
        at origin: Int,
        declaring holding: [Symbol],
        leaning dependencies: [Fingerprint]?,
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
        var variables: [Name: Value] = [:]

        func context() -> TypingContext {
            compiling.context(reading: reading)
        }

        func row(of symbol: Symbol) throws -> Int {
            guard let row = compiling.lowering.rows[symbol.declared] else {
                throw BuildError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        // The names in scope before a body's first statement: its parameters,
        // the constants its module declared beside them, and the variables. A
        // variable stands in the environment as a box whose type is fixed:
        // what a write puts in it has to fit what it started as, because every
        // body of the document reads it as that.
        func opening(_ signature: Signature) -> [Name: LoweredType] {
            environment(of: signature, in: loweredTypes)
                .merging(constants.mapValues { value in type(of: value, in: loweredTypes) }) { _, constant in
                    constant
                }
                .merging(
                    variables.mapValues { value in .inout(type(of: value, in: loweredTypes)) }
                ) { _, variable in variable }
        }

        // One declaration resolves once, whichever table asks.
        var resolvedBodies: [Name: (procedure: Procedure, calls: [CallSite])] = [:]

        // A declaration, bound and dot-judged: selectors resolve to declared
        // spellings, every dot in the body is spelled as what the types say it
        // means, and a constant-headed path (judged first, like any path) folds
        // to the value it is. The image holds only this form, so a run never
        // asks a value what a name does.
        //
        // Every call the body writes is checked here too: whatever table put
        // this body in the image, the body runs, so the frontier's promise
        // (callee declared, arguments taken) is kept per body rather than per
        // reachability.
        func resolved(_ symbol: Symbol) async throws -> (procedure: Procedure, calls: [CallSite]) {
            if let done = resolvedBodies[symbol.declared] { return done }

            let declaration = symbol.procedure

            var answer = (procedure: declaration, calls: [CallSite]())

            if let block = declaration.block {
                // A body not yet lowered stands as its refusal, so a procedure
                // folding through a procedure is refused as the cycle it is.
                let folding = Folding(
                    constants: constants,
                    origin: origin,
                    in: compiling.folding(),
                    loweredTypes: loweredTypes
                )

                // The starting environment knows the constants beside the
                // parameters, so a constant-headed path is judged against the
                // type of the value it will fold to.
                let (rewritten, gathered) = try await resolvedSites(
                    in: block,
                    at: symbol.place,
                    in: opening(declaration.signature),
                    answering: declaration.signature.returns,
                    with: context(),
                    folding: folding,
                    origin: origin,
                    writing: fulfillment
                )

                answer = (
                    procedure: Procedure(
                        description: declaration.description,
                        signature: declaration.signature,
                        implementation: .body(rewritten)
                    ),
                    calls: gathered
                )
            }

            resolvedBodies[symbol.declared] = answer

            try checked(answer.calls, in: context(), writing: fulfillment)

            // Read off the body the build is about to lower, so what is proven
            // is what runs. The environment is the one the body was judged in.
            if let rewritten = answer.procedure.block {
                try consumed(
                    rewritten,
                    at: symbol.place,
                    holding: declaration.signature,
                    in: context()
                )
            }

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                try compiling.settle(try row(of: symbol), body: rewritten, at: symbol.place)
            }

            return answer
        }

        // The facts nobody declared. All three are fixed points over what a
        // body reaches, so a document's answer is settled once the documents
        // it reaches have theirs, and the standing refused a ring where that
        // is not so. Read over every declaration the document holds rather
        // than the reached ones: a path names a procedure the call graph never
        // mentions.
        //
        // What this document declares, by the spelling a call in it writes.
        // Its own rows do not stand yet, and this is what says what they take
        // until they do.
        let own = holding.reduce(into: [Name: Signature]()) { asked, symbol in
            asked[symbol.declared] = symbol.procedure.signature
        }

        // What a selector this document may reach takes: its own declarations
        // first, the documents standing before it after. One rule, so the two
        // judgements standing on it read the same declaration.
        let taking: @Sendable (Name) -> Signature? = {
            [rows = compiling.lowering.rows, table = compiling.lowering.table] selector in
            own[selector] ?? rows[selector].map { row in table[row].signature }
        }

        const(among: holding, settling: &compiling.const, reading: reading)
        isolated(among: holding, settling: &compiling.isolated, taking: taking)
        failing(among: holding, settling: &compiling.failing)

        // Where this document numbers its calls from: what it looks for
        // outside itself first, its own declarations after. Built from the
        // document alone, so a body lowers to the same numbers whatever
        // else the caller put in the link.
        let numbering = Numbering(
            imports: module.imports,
            declared: declared,
            closures: module.closures
        )
        let sending = Sending(
            numbering: numbering,
            const: compiling.const,
            isolated: compiling.isolated,
            taking: taking
        )

        // This document's block of the table, in name order. What a
        // document declares is a run of rows rather than declarations
        // scattered through the table, so where its rows begin is a number
        // and its own are that number and an offset. A native answers as
        // it is from the start; a written body stands as the refusal it
        // would earn until it is lowered, so nothing folds through a body
        // half-made.
        let block = compiling.hold(
            origin,
            standing: try holding.map { symbol in
                Linked.standing(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    const: compiling.const.contains(symbol.declared),
                    isolated: compiling.isolated.contains(symbol.declared),
                    failing: compiling.failing[symbol.declared] ?? .unstated,
                    builtin: module.builtin,
                    sends: try sending.rows(of: symbol.procedure, called: symbol.declared),
                    in: loweredTypes
                )
            },
            numbering: numbering,
            variables: boxes
        )

        compiling.answering(origin)

        // The bodies the documents behind this one lowered, which this one
        // may run.
        compiling.foldable()

        // Settled after the procedures are known, because a constant may call
        // one: interpolation is `joined` now, and a constant that spells a
        // URL out of other constants is spelling it with procedures like any
        // other expression.
        //
        // The context is read before the lowering is handed over, since one of
        // the tables a context stands on is the lowering this writes into.
        constants = try await self.constants(
            of: module,
            at: origin,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            leaning: fulfillment,
            in: context()
        )

        variables = try await self.variables(
            of: module,
            at: origin,
            beside: constants,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            leaning: fulfillment,
            in: context()
        )

        // What every declaration of this document whose `returns` nobody
        // wrote answers, read off its body.
        await answers(
            of: holding.compactMap { symbol -> Unsaid? in
                guard
                    symbol.procedure.signature.returns == nil,
                    let block = symbol.procedure.block
                else { return nil }

                return Unsaid(
                    symbol: symbol,
                    block: block,
                    environment: opening(symbol.procedure.signature),
                    sends: sent(in: block)
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
        // whether or not this entry walks that way, so which declarations
        // are judged is not a question the entry answers.
        for symbol in holding {
            try await fulfillment.folding(symbol.place) {
                let (procedure, _) = try await resolved(symbol)

                // A constant answer is a value and not only a type, so it is
                // held to what the declaration admits as well as to what it
                // reads as, the way a constant argument is.
                if let returns = procedure.signature.returns,
                   let answer = procedure.block?.result?.constantValue {
                    do {
                        _ = try returns.lowered(in: loweredTypes).settling(answer, at: "answer", in: loweredTypes)
                    } catch {
                        throw BuildError(
                            "answers \(answer.type), and its"
                                + " declaration promises \(returns): \(error)",
                            at: symbol.place.part(.result)
                        )
                    }
                }
            }
        }

        // The types its bodies stand on, written as this document's own
        // numbers. Lowering read the link's table to judge, so what it wrote
        // is that link's rows; what leaves here is the document's.
        //
        // Its rows are its declarations in name order, then the closures its
        // bodies lifted, in the order it numbers them.
        let lowered = try compiling.lowering.numbered(
            Array(block) + (compiling.lowering.closureRows[origin] ?? []),
            of: origin,
            answering: read
        )

        return Compiled(
            document: .of(module),
            types: module.types,
            constraints: module.constraints,
            contracts: module.contracts,
            claims: module.claims,
            leaned: fulfillment.claims(of: origin),
            declared: declared,
            table: lowered.table.map(Judged.init),
            answers: lowered.answers,
            numbering: numbering,
            typeNumbering: lowered.numbering,
            variables: boxes.map { name in (name: name, value: variables[name] ?? .null) },
            dependencies: dependencies
        )
    }

    // Which row a run starts from, and which declarations it reaches. Nothing
    // runs here: every declaration stands compiled already, and the answer is
    // read off the call graph the compile gathered.
    //
    // What is judged here is what no document could answer about itself, and
    // is the second judgement for that reason: the entry names a declaration,
    // every claimed type answers the contract it is claimed under, and every
    // constraint a document leaned on is held by some document beside it.
    // `supplying` is the native code the documents named. An object says
    // which of its procedures are native and holds none of the code, so the modules
    // that declared them are handed over beside the objects.
    public func link(
        _ compiled: [Compiled],
        entry: Name,
        supplying natives: Supplying
    ) throws -> Image {
        // Every document's block laid down, which is where its rows first
        // stand somewhere. What a name reaches is answered from here on.
        let assembled = try Assembled(compiled)

        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it.
        guard let start = assembled.rows[entry] else {
            throw BuildError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(assembled.rows.keys.sorted().map(\.spelling).joined(separator: ", "))",
                at: nil
            )
        }

        // The types of this link, made from what its documents declared and
        // laid down in the order their blocks are. Which types answer which
        // contracts is read across the documents, so the rows a body stands on
        // are answered here rather than carried out of a compile.
        let declared = try declared(in: compiled)
        let declaring = try self.types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: compiled,
            standing: Array(compiled.indices),
            numbered: Linkage()
        )
        let signatures = assembled.rows.reduce(into: [Name: Placed<Signature>]()) { table, entry in
            let origin = assembled.origins[entry.value]

            table[entry.key] = Placed(
                assembled.table[entry.value].signature,
                at: .procedure(entry.key.spelling, in: compiled[origin].document),
                of: origin
            )
        }

        let lowered = try lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures
        )
        let types = lowered.types

        // What each document leaned on, answered by every claim in the list.
        for document in compiled {
            try leaning(
                document.leaned,
                on: types.loweredTypes.satisfying,
                unheld: lowered.unheld
            )
        }

        // The documents' own numbers turned into this link's rows, and the
        // calls through a contract filled with the rows that answer them.
        let relocating = try Relocating(assembled, types: types, supplied: natives)
        let linked = try relocating.linked()
        let variables = try relocating.started(assembled.variables)

        // Walked as rows, reported as spellings: a closure is a row without
        // one and is walked through, and only what has one is reported.
        let rows = reached(from: start, over: linked.table, starting: variables)
        let spellings = Set(assembled.rows.lazy.filter { entry in rows.contains(entry.value) }.map(\.key))

        return Image(
            linked: linked.table,
            start: start,
            rows: assembled.rows,
            reached: spellings,
            types: types,
            variables: variables
        )
    }

    // MARK: - Private
    // Which rows a run entering at this one can reach, following what each
    // row's code names, and the closures a variable it reads starts out
    // holding. Transitive. Every number met is a row of this table, since the
    // link answered each one before the table was handed over.
    private func reached(
        from start: Int,
        over table: [Linked],
        starting variables: [[(name: Name, value: Value)]]
    ) -> Set<Int> {
        var reached: Set<Int> = []
        var frontier = [start]

        while let row = frontier.popLast() {
            guard reached.insert(row).inserted else { continue }

            frontier.append(contentsOf: table[row].reaches)

            for variable in table[row].variables {
                variables[table[row].origin][variable].value.closures { closure in
                    frontier.append(closure.number)

                    return true
                }
            }
        }

        return reached
    }
}
