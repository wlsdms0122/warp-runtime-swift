//
//  Builder.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this link was given and answers with an image, or
// refuses.
//
// A build is handed its whole module graph at once. The procedures a program can
// call are the procedures the caller put in front of it, so what to build is the
// caller's statement and joining the names up is this. A module's `imports` says what it
// asks for and never where to find it. Which declaration a run starts from is
// the run's argument: an image is every declaration the link judged, and a
// caller starts a run from any public one.
//
// Every declaration is judged. A misspelled procedure in an arm today's
// arguments never take is a defect whether or not a run walks that way, and so
// is one in a declaration no run calls.
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
// Two stages. Compiling settles everything a document says against the
// interfaces it reaches: its declarations (`DeclarationChecker`), what it
// claims (`ClaimChecker`), the facts nobody declared (`Derivation`), its
// bodies (`TypeChecker`, `LinearityChecker`) and lowering (`Lowering`). It
// runs the procedures a constant calls, which is what folding is. Linking
// takes what that answered and one name to start from, judges what only the
// whole list can answer, and runs nothing.
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
    // What to build is the caller's statement, the whole graph at once. A
    // bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func build(_ modules: [Module]) async throws -> Image {
        try await link(compile(modules), supplying: Supplying(modules))
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

        try against(compiled)

        // Laid end to end through the door a link lays documents through, so a
        // name two of them declare is refused here as it is there.
        let assembled = try Assembled(compiled)
        let linkage = Linkage()
        let declared = try declared(in: compiled)
        let declaring = try DeclarationChecker().types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: compiled,
            standing: Array(compiled.indices),
            numbered: linkage
        )

        let signatures = signatures(of: assembled)

        // Which types answer which contracts among these documents. A row
        // whose signature names a contract lowers against that reading, so it
        // is worked out here rather than left to the compile that asks.
        let lowered = try ClaimChecker().lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures
        )

        var compiling = Compiling(
            types: lowered.types,
            contractProcedures: lowered.contractProcedures,
            naming: compiled.map(\.document),
            spelling: compiled.map(\.naming)
        )

        for (origin, document) in compiled.enumerated() {
            let numbered = document.typeNumbering.rows(in: lowered.types.loweredTypes)

            let rows = try document.table.enumerated().map { index, judged -> Linked in
                let row = try judged.folding(
                    in: lowered.types.loweredTypes,
                    of: origin,
                    nth: document.nth(ofRow: index),
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

        try compiling.answerHeld()
        try compiling.answering()

        var declarers = DeclarerTable()

        for origin in compiled.indices {
            declarers.lay(compiled[origin])
        }

        return Laid(
            compiled: compiled,
            carried: compiling.carried,
            signatures: signatures,
            linkage: linkage,
            naming: compiled.indices.map { origin in compiled[origin].naming },
            identities: Set(compiled.indices.compactMap { origin in compiled[origin].identity }),
            declarers: declarers
        )
    }

    // The same, against documents a caller already laid down.
    public func compile(_ modules: [Module], against laid: Laid) async throws -> [Compiled] {
        let compiled = laid.compiled

        try once(modules, held: laid.identities)

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
            contracts: [Name: Placed<[Name: ContractProcedure]>],
            claims: [Placed<Claim>]
        ),
        against laid: Laid
    ) async throws -> [Compiled] {
        let compiled = laid.compiled
        let laying = standing.map { position in modules[position] }
        let documents: [any Declaring] = compiled + laying

        let declaring = try DeclarationChecker().types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: documents,
            standing: Array(documents.indices),
            numbered: laid.linkage
        )

        try DeclarationChecker().judge(laying, in: declaring)

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
            // A private declaration takes no spelling from the link, so it is
            // neither held to a spelling another document took nor in the
            // space another document resolves in.
            for symbol in symbols where symbol.supplies {
                if let first = signatures[symbol.declared] {
                    throw BuildError(
                        "'\(symbol.declared)' is declared by \(first.spelled) and by"
                            + " \(symbol.spelled). Two declarations of a name have no way"
                            + " to be told apart",
                        at: symbol.place
                    )
                }

                signatures[symbol.declared] = Placed(
                    Declared(signature: symbol.procedure.signature, access: symbol.procedure.access),
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
        let lowered = try ClaimChecker().lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures,
            concealed: laid.carried.concealed.union(holding.flatMap { symbols in
                symbols.filter { symbol in !symbol.supplies }.map(\.declared)
            }),
            unsettled: fulfillment
        )

        // A document never written down is told from another by this compile
        // of it, so each is given that here and carries it out.
        let tokens = laying.map { _ in Compiled.Token() }
        var compiling = Compiling(
            laid.carried,
            types: lowered.types,
            contractProcedures: lowered.contractProcedures,
            naming: documents.map(\.document),
            spelling: laid.naming + zip(laying, tokens).map { module, token in
                Closure.Document(identity: module.identity, token: token)
            }
        )

        // What each document turned out to be, as they are laid down. A
        // document laid here may be what the next one leans on, and what it
        // leaned on is part of what it is, so the two grow together.
        var declarers = laid.declarers
        var built: [Compiled] = []

        for offset in laying.indices {
            let object = try await compile(
                laying[offset],
                at: compiled.count + offset,
                declaring: holding[offset],
                leaning: declarers.dependencies(of: laying[offset]),
                as: tokens[offset],
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
        var variables: [Name: Value] = [:]

        // The constants with what each reads as: what seeds the environment a
        // body is judged in, and what a body binds where it reads one at an
        // index the run settles.
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
            TypeChecker().environment(of: signature, in: loweredTypes)
                .merging(typedConstants.mapValues { constant in .fixed(constant.type) }) { _, constant in
                    constant
                }
                .merging(
                    variables.reduce(into: [Name: Binding]()) { held, entry in
                        held[entry.key] = .declared(
                            module.variables[entry.key]?.declared?.lowered(in: loweredTypes)
                                ?? TypeChecker().type(of: entry.value, in: loweredTypes)
                        )
                    }
                ) { _, variable in variable }
        }

        // One declaration resolves once, whichever table asks.
        var resolvedBodies: [Name: Procedure] = [:]

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
        func resolved(_ symbol: Symbol) async throws -> Procedure {
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
                let (rewritten, gathered) = try await TypeChecker().resolvedSites(
                    in: block,
                    at: symbol.place,
                    in: opening(declaration.signature),
                    answering: declaration.signature.returns,
                    with: context().bounding(declaration.signature.parameterBounds.table),
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

            resolvedBodies[symbol.declared] = answer.procedure

            try TypeChecker().checked(answer.calls, in: context(), writing: fulfillment)

            // Read off the body the build is about to lower, so what is proven
            // is what runs. The environment is the one the body was judged in.
            if let rewritten = answer.procedure.block {
                try LinearityChecker().consumed(
                    rewritten,
                    at: symbol.place,
                    holding: declaration.signature,
                    in: context()
                )
            }

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                try compiling.settle(try row(of: symbol), body: rewritten, constants: typedConstants, at: symbol.place)
            }

            return answer.procedure
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
            [rows = compiling.lowering.rows, table = compiling.lowering.table, asked = compiling.contractProcedures] selector in
            own[selector] ?? rows[selector].map { row in table[row].signature } ?? asked[selector]?.signature
        }

        // Derived over this document's declarations, and read off the rows
        // the link holds for every other: what the build derives of a
        // declaration stands on its row, so a document's own facts are its
        // own until its rows stand, and a spelling another document declares
        // privately is no row this one reaches.
        var const: Set<Name> = []
        var isolated: Set<Name> = []
        var failing: [Name: Failing] = [:]
        let beyond: @Sendable (Name) -> Linked? = { [compiling] selector in compiling.declared(selector, from: origin) }

        // A call through a contract reaches whatever declaration the value
        // turns out to be, so what it reads as is what the contract asked of
        // every one of them.
        let asked = compiling.contractProcedures
        let answersWithoutRunning: @Sendable (Name) -> Bool = { selector in
            beyond(selector)?.constness == .const || asked[selector]?.constness == .const
        }
        let touchesNothingShared: @Sendable (Name) -> Bool = { selector in
            beyond(selector)?.isolation == .isolated || asked[selector]?.isolation == .isolated
        }

        Derivation().const(among: holding, settling: &const, reading: reading, taking: taking, beyond: answersWithoutRunning)
        Derivation().isolated(among: holding, settling: &isolated, taking: taking, beyond: touchesNothingShared)
        Derivation().failing(among: holding, settling: &failing) { selector in beyond(selector)?.failing }

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
        // else the caller put in the link.
        let numbering = Numbering(
            sends: module.sends,
            declared: declared,
            closures: module.closures
        )
        let sending = Sending(
            numbering: numbering,
            const: constant,
            isolated: untouched,
            taking: taking,
            in: loweredTypes
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
                    const: const.contains(symbol.declared),
                    isolated: isolated.contains(symbol.declared),
                    failing: failing[symbol.declared] ?? .unstated,
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

        typedConstants = constants.mapValues { value in (value: value, type: TypeChecker().type(of: value, in: loweredTypes)) }

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
                let procedure = try await resolved(symbol)

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

        // Through the one door an object read back goes through, so what a
        // compile stands up is what a reading would take.
        return try Compiled(
            document: .of(module),
            types: module.types,
            constraints: module.constraints,
            contracts: module.contracts,
            claims: module.claims,
            leaned: fulfillment.claims(of: origin),
            declared: declared,
            constants: module.constants.keys.sorted(),
            table: lowered.table.map(Judged.init),
            answers: lowered.answers,
            numbering: numbering,
            typeNumbering: lowered.numbering,
            judging: boxes.map { name in (name: name, value: variables[name] ?? .null) },
            dependencies: dependencies,
            token: token
        )
    }

    // The documents laid down as one table of rows. Nothing runs here: every
    // declaration stands compiled already, and the rows are relocated into
    // this link's numbering.
    //
    // What is judged here is what no document could answer about itself, and
    // is the second judgement for that reason: every claimed type answers the
    // contract it is claimed under, and every constraint a document leaned on
    // is held by some document beside it. `supplying` is the native code the
    // documents named. An object says which of its procedures are native and
    // holds none of the code, so the modules that declared them are handed
    // over beside the objects.
    public func link(
        _ compiled: [Compiled],
        supplying natives: Supplying
    ) throws -> Image {
        try against(compiled)

        // Every document's block laid down, which is where its rows first
        // stand somewhere. What a name reaches is answered from here on.
        let assembled = try Assembled(compiled)

        // The types of this link, made from what its documents declared and
        // laid down in the order their blocks are. Which types answer which
        // contracts is read across the documents, so the rows a body stands on
        // are answered here rather than carried out of a compile.
        let declared = try declared(in: compiled)
        let declaring = try DeclarationChecker().types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: compiled,
            standing: Array(compiled.indices),
            numbered: Linkage()
        )
        let signatures = signatures(of: assembled)

        let lowered = try ClaimChecker().lowered(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            over: declared.types,
            among: signatures,
            concealed: assembled.concealed
        )
        let types = lowered.types

        // What each document leaned on, answered by every claim in the list.
        for document in compiled {
            try ClaimChecker().leaning(
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

        return Image(
            linked: linked.table,
            rows: assembled.rows,
            concealed: assembled.concealed,
            types: types,
            variables: variables,
            naming: assembled.naming
        )
    }

    // MARK: - Private
    // Every object standing beside what it was compiled against. An object
    // says what it leaned on by fingerprint, and what it settled, a closure
    // spelled by a document's name and count among them, is true against
    // exactly those compiles of them. A document that leaned on nothing a
    // fingerprint was worked out for says nothing here. One that did is
    // held to it, document by document: what it leaned on stands beside it
    // under the fingerprint it had then, or the document is not laid.
    private func against(_ compiled: [Compiled]) throws {
        let present = Set(compiled.indices.compactMap { origin in compiled[origin].fingerprint })

        for origin in compiled.indices {
            guard let dependencies = compiled[origin].dependencies,
                  let missing = dependencies.first(where: { fingerprint in !present.contains(fingerprint) })
            else {
                continue
            }

            throw BuildError(
                "\(compiled[origin].document.spelled(at: origin)) was compiled against a document"
                    + " (\(missing)) that is not laid beside it as it was then",
                at: Place(in: compiled[origin].document)
            )
        }
    }

    // An object said as what it is, where the caller handed over how that is
    // worked out. One that cannot be written down has nothing to work it out
    // from, which is the same absence said one step earlier.
    private func fingerprinted(_ object: Compiled) throws -> Compiled {
        guard let fingerprinting else { return object }

        // Nothing to work a fingerprint out from, for one of the reasons an
        // object has none, and none of them is something that went wrong. The
        // document stands without one.
        guard let written = try? object.object() else { return object }

        return object.fingerprinted(try fingerprinting(written))
    }

    // Every declaration the documents laid down made, under the spelling it
    // was declared by and at the place it was written. What a document
    // declares is its own; where it stands among the documents is the
    // caller's order.
    private func signatures(of assembled: Assembled) -> [Name: Placed<Declared>] {
        assembled.rows.reduce(into: [Name: Placed<Declared>]()) { table, entry in
            let row = assembled.table[entry.value]

            table[entry.key] = Placed(
                Declared(
                    signature: row.judged.signature,
                    access: row.judged.access,
                    facts: (row.judged.constness, row.judged.isolation)
                ),
                at: .procedure(entry.key.spelling, in: assembled.documents[row.origin]),
                of: row.origin
            )
        }
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
    private func once(_ modules: [Module], held: Set<Identity> = []) throws {
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
    private func symbols(of modules: [Module], after held: Int = 0) throws -> [Symbol] {
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

    // A document's constants, settled. They are evaluated here because there is
    // nothing about them left for a run to do: a constant sees no scope, so what
    // it will be is knowable the moment the document is read.
    //
    // One may name another declared beside it, so they are settled in the order
    // they read each other and that order is worked out first. What is wrong
    // with a set of constants is a fact about that order, and asking the order
    // is the whole of finding it.
    private func constants(
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
                let (judged, calls) = try await TypeChecker().resolvedSites(
                    in: expression,
                    at: place,
                    in: known.mapValues { value in .fixed(TypeChecker().type(of: value, in: context.loweredTypes)) },
                    with: context,
                    folding: nil,
                    writing: fulfillment
                )

                // A closure a constant holds runs later, so evaluating the
                // constant proves nothing about the sends inside it. They pass
                // the same gate every gathered call does.
                try TypeChecker().checked(calls, in: context, writing: fulfillment)

                // A constant settles at the build, so what it is written from
                // is read rather than run. The same gate an operand passes,
                // asked here because a constant is the one other place the
                // build reads an expression instead of running it.
                try TypeChecker().settles(judged, at: place, given: context, writing: fulfillment)

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
    // and no variable; the starting value is a fact the link reads. A variable
    // that declares what it holds has its start settled into that, the way an
    // argument is settled into its slot, and holds that type; one that
    // declares nothing holds the type of the settled value.
    private func variables(
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

        for (name, variable) in module.variables.sorted { $0.key < $1.key } {
            let place = Place.variable(name.spelling, in: .of(module))

            try await fulfillment.folding(place) {
                let (judged, calls) = try await TypeChecker().resolvedSites(
                    in: variable.start,
                    at: place,
                    in: known.mapValues { value in .fixed(TypeChecker().type(of: value, in: context.loweredTypes)) },
                    with: context,
                    folding: nil,
                    writing: fulfillment
                )

                try TypeChecker().checked(calls, in: context, writing: fulfillment)

                // A variable's starting value settles at the build the way a
                // constant's does, so it passes the same gate.
                try TypeChecker().settles(judged, at: place, given: context, writing: fulfillment)

                let settled: Value

                do {
                    settled = try await Folding(
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

                guard let declared = variable.declared else {
                    started[name] = settled
                    return
                }

                let holding = declared.lowered(in: context.loweredTypes)

                if case let .undeclared(label, _) = holding {
                    throw BuildError("declares type '\(label)', which nothing declares", at: place)
                }

                do {
                    started[name] = try holding.settling(settled, at: "the start of '\(name)'", in: context.loweredTypes)
                } catch {
                    throw BuildError(
                        "starts as \(TypeChecker().type(of: settled, in: context.loweredTypes).rendered(in: context.loweredTypes)),"
                            + " and declares \(declared): \(error)",
                        at: place
                    )
                }
            }
        }

        return started
    }

    // The order a module's constants settle in: what a constant reads comes
    // before it. Constants that wait on each other have no such order, and that
    // is refused here, standing on one of them.
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

    // Type, constraint and contract names are their declared spelling, the way
    // procedure names are: the standard bundles declare `std.Numeric` under that
    // key, and a document declaring a bare `Numeric` of its own declares a
    // different name.
    //
    // The three tables gathered whole, here and nowhere else, so the uniqueness
    // this pass refuses on is the same fact the tables are built from: each is
    // filled as it is walked. A mention nothing declares is
    // refused by the judgment that owns undeclared names, which says where the
    // mention lives.
    private func declared(in documents: [any Declaring]) throws -> (
        types: [Name: Placed<TypeExpression>],
        constraints: [Name: Placed<[TypeExpression]>],
        contracts: [Name: Placed<[Name: ContractProcedure]>],
        claims: [Placed<Claim>]
    ) {
        // Where each name was written, gathered here and carried with what it
        // holds. This is where both halves of the joining are in hand. Anywhere
        // later has only the joined name, and taking it apart again is a second
        // copy of a rule that has to be right once.
        //
        // One table per space, and the table is what says a name is taken. A
        // second table beside it saying the same thing is a second answer to
        // one question.
        //
        // Each space is walked whole before the two are held against each
        // other, so what a link concludes cannot depend on the order the caller
        // happened to list the documents in.
        var declaredTypes: [Name: Placed<TypeExpression>] = [:]
        var declaredConstraints: [Name: Placed<[TypeExpression]>] = [:]
        var declaredContracts: [Name: Placed<[Name: ContractProcedure]>] = [:]

        for (origin, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(type, at: .type(name.spelling, in: held.document), of: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = declaredTypes[name] {
                    throw BuildError(
                        "type '\(name)' is declared more than once in this link, by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                declaredTypes[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, members) in held.constraints.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(
                    members,
                    at: .constraint(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name] {
                    throw BuildError(
                        "'\(name)' is declared as both a type and a constraint in"
                            + " this link, as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled). One name cannot"
                            + " stand for a type and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = declaredConstraints[name] {
                    throw BuildError(
                        "constraint '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                declaredConstraints[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, procedures) in held.contracts.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(
                    procedures,
                    at: .contract(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name]?.spelled ?? declaredConstraints[name]?.spelled {
                    throw BuildError(
                        "'\(name)' is declared as a contract in this link and as"
                            + " something else by \(declared). One name"
                            + " cannot be a type, a membership and a contract"
                            + " at once",
                        at: declaration.place
                    )
                }

                if let first = declaredContracts[name] {
                    throw BuildError(
                        "contract '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                guard !procedures.isEmpty else {
                    throw BuildError(
                        "asks nothing, so every type satisfies it. A contract is"
                            + " the procedures a value answers, and one with no procedures"
                            + " says nothing a slot could lean on",
                        at: declaration.place
                    )
                }

                declaredContracts[name] = declaration
            }
        }

        // What each document said one of its types, or another document's,
        // answers. Handed on as a list, since a claim declares no name for a
        // table to be keyed by.
        //
        // A pair two documents claim is one claim. A claim holds nothing but
        // the pair, so two of them cannot disagree, and the second says what
        // the first said.
        var claimed: Set<Claim> = []
        var claims: [Placed<Claim>] = []

        for (origin, held) in documents.enumerated() {
            for (type, contracts) in held.claims.sorted(by: { $0.key < $1.key }) {
                for contract in contracts.sorted() {
                    let claim = Claim(type: type, contract: contract)

                    guard claimed.insert(claim).inserted else { continue }

                    claims.append(
                        Placed(
                            claim,
                            at: .satisfies(type.spelling, in: held.document),
                            of: origin
                        )
                    )
                }
            }
        }

        return (declaredTypes, declaredConstraints, declaredContracts, claims)
    }
}
