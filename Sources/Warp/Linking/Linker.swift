//
//  Linker.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this run was given and one name to start from, and answers
// with an image, or refuses.
//
// A link is handed its whole module graph at once. The words a program can call are
// the words the caller put in front of it, so what to link is the caller's
// statement and joining the names up is this. A module's `imports` says what it
// asks for and never where to find it, and the entry is an argument rather than
// a name written into a document.
//
// Every declaration is judged, not the reached ones. A misspelled procedure in
// an arm today's arguments never take is a defect whether or not this run walks
// that way, and so is one in a declaration this entry never calls. The entry
// says which declarations a run reaches and nothing about which ones hold.
//
// Every call goes through the same gate: a library word and a procedure are
// checked against a signature by the same code, and the only difference is
// where the signature came from. The installed table, or another module in the
// same link.
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
// everything the documents say on their own: resolving (`Linker+Resolving`),
// the facts nobody declared (`Linker+Deriving`, `Linker+Isolating`), judging
// (`Linker+Judging`, `Linker+Typing`) and lowering (`Lowering`). It runs the
// words a constant calls, which is what folding is. Linking takes what that
// answered and one name to start from, and runs nothing.
public struct Linker: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // The second judgement, and the one a module cannot make about itself: a
    // module is checked against itself, an image is checked across every module
    // given.
    //
    // What to link is the caller's statement (the whole graph at once) and
    // `entry` names which declaration this run starts from. There is no
    // default: guessing which procedure was meant would be an opinion nobody
    // gave.
    //
    // A bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func link(_ modules: [Module], entry: Name) throws -> Image {
        try link(compile(modules, in: gathering(of: modules)), entry: entry)
    }

    // MARK: - Internal
    // Everything the documents settle on their own. No entry reaches in here:
    // what a document says has to hold whichever declaration a run starts
    // from.
    //
    // What the whole list answered is handed over rather than read again. A
    // document has no say in any of it.
    func compile(_ modules: [Module], in gathered: Gathered) throws -> Compiled {
        // Every judgment the link asks and every row it builds reads the
        // table the run will read.
        let shapes = gathered.types.shapes

        // Purity is worked out over every declaration rather than the reached
        // ones: a path names a word the call graph never mentions.
        let moduleVariables = modules.enumerated().reduce(into: [Int: Set<Name>]()) { table, entry in
            table[entry.offset] = Set(entry.element.variables.keys)
        }

        // What each document declares, in name order, which is the order its
        // rows stand in.
        let held = gathered.symbols.reduce(into: [Int: [Symbol]]()) { table, symbol in
            table[symbol.origin, default: []].append(symbol)
        }

        // What the documents already laid down proved, which is what the next
        // one is compiled against.
        var settled: Set<Name> = []
        var isolatedDeclarations: Set<Name> = []
        var failingDeclarations: [Name: Failing] = [:]

        // What the link read off a body whose declaration wrote no `returns`.
        // Only those: what a declaration wrote is on its row already, and a
        // table holding every spelling would hash every declared name to say
        // what the row says.
        var answered: [Name: Shape] = [:]
        var wordAnswered = [[Name: Shape]](repeating: [:], count: modules.count)

        // Which declarations each document's paths step to, and the three
        // readings of that table the walk asks for. What a bare spelling may
        // call is its own table rather than a mask over the declarations,
        // because a selector and a path segment ask two questions: what a call
        // reaches, and what a step may reach. One table masked by a set let one
        // spelling answer with the other question's declaration.
        //
        // What a selector reaches is asked of the declarations themselves,
        // which is where an author's signature already stands.
        var wordSymbols = [[Name: Symbol]](repeating: [:], count: modules.count)
        var answeringWords = [[Name: Signature]](repeating: [:], count: modules.count)

        // Which spellings a path reaches one declaration by. A word may be
        // reachable under more than one, and an answer worked out for it is
        // that declaration's however a walk spelled it.
        var wordSpellings = [[Name: [Name]]](repeating: [:], count: modules.count)

        // What each document declares and what its variables are called, in
        // the order the rows and the boxes stand in.
        var declaredBy = [[Name]](repeating: [], count: modules.count)
        var orderedVariables = [[Name]](repeating: [], count: modules.count)

        // The rows, and where every number a body carries stands. Held here
        // and read from here: a second holder of a growing table makes every
        // write to it copy the whole thing.
        var lowering = Lowering(
            documents: modules.count,
            contractWords: gathered.contractWords,
            shapes: shapes
        )

        // Which row each document's numbers stand for, answered when the
        // document is laid down. A number of its own reaches a name it
        // declared or one behind it, so the answer never moves after that.
        var named: [Int: [Int?]] = [:]

        // The rows folding runs against, held here rather than read off the
        // lowering: a row is written in when the phase that lowered it ends,
        // so what a body folds through is what stood settled before its phase
        // began rather than whatever the row order reached first. Lowering is
        // then the only holder of its own table, and writing a row into it
        // copies nothing.
        var foldingRows: [Linked] = []
        var loweredRows: [Int] = []

        // The stand-ins, while the words themselves settle: a word folding
        // through a word would be a circle, and which words are already
        // lowered is a fact of name order rather than of the text.
        func foldingTable() -> Answered {
            Answered.documents(
                foldingRows,
                rows: lowering.rows,
                words: lowering.words,
                numbering: lowering.numbering,
                named: named,
                closures: lowering.closureRows
            )
        }

        // What has been lowered since the last phase, written in.
        func foldable() {
            foldingRows.append(contentsOf: lowering.table[foldingRows.count...])

            for row in loweredRows {
                foldingRows[row] = lowering.table[row]
            }

            loweredRows.removeAll(keepingCapacity: true)
        }

        func row(of symbol: Symbol) throws -> Int {
            guard let row = lowering.rows[symbol.declared] else {
                throw LinkError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        // One document's reading. What a path may walk to is the document's
        // own, so a frame is made for the document whose body is being read.
        func frame(for origin: Int) -> TypeFrame {
            TypeFrame(
                symbols: gathered.space,
                types: gathered.types,
                linked: lowering.table,
                rows: lowering.rows,
                answers: answered,
                words: answeringWords[origin],
                wordRows: lowering.words[origin],
                wordAnswers: wordAnswered[origin],
                pure: settled,
                isolated: isolatedDeclarations,
                failing: failingDeclarations,
                contractWords: gathered.contractWords,
                variables: moduleVariables
            )
        }


        // What each document settled, filled as the walk reaches it.
        var constants: [Int: [Name: Value]] = [:]
        var variables: [Int: [Name: Value]] = [:]
        var calls: [Name: [Name]] = [:]

        // The names in scope before a body's first statement: its parameters,
        // the constants its module declared beside them, and the variables. A
        // variable stands in the environment as a box whose type is fixed:
        // what a write puts in it has to fit what it started as, because every
        // body of the document reads it as that.
        func opening(_ symbol: Symbol, of signature: Signature) -> [Name: Shape] {
            environment(of: signature, in: shapes)
                .merging(
                    (constants[symbol.origin] ?? [:]).mapValues { value in type(of: value, in: shapes) }
                ) { _, constant in constant }
                .merging(
                    (variables[symbol.origin] ?? [:]).mapValues { value in .inout(type(of: value, in: shapes)) }
                ) { _, variable in variable }
        }

        // One declaration resolves once, whichever table asks. The frontier for
        // a reached body, the derivable tables for a body a path may run.
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
        func resolved(_ symbol: Symbol) throws -> (procedure: Procedure, calls: [CallSite]) {
            if let done = resolvedBodies[symbol.declared] { return done }

            let declared = symbol.procedure

            var answer = (procedure: declared, calls: [CallSite]())

            if let block = declared.block {
                // A body not yet lowered stands as its refusal, so a word
                // folding through a word is refused as the circle it is.
                let folding = Folding(
                    constants: constants[symbol.origin] ?? [:],
                    origin: symbol.origin,
                    in: foldingTable(),
                    shapes: shapes
                )

                // The starting environment knows the constants beside the
                // parameters, so a constant-headed path is judged against the
                // type of the value it will fold to.
                let environment = opening(symbol, of: declared.signature)

                let (rewritten, gathered) = try resolvedSites(
                    in: block,
                    at: symbol.place,
                    in: environment,
                    with: frame(for: symbol.origin),
                    folding: folding,
                    origin: symbol.origin
                )

                answer = (
                    procedure: Procedure(
                        description: declared.description,
                        signature: declared.signature,
                        implementation: .body(rewritten)
                    ),
                    calls: gathered
                )

            }

            resolvedBodies[symbol.declared] = answer

            try checked(answer.calls, in: frame(for: symbol.origin))

            // Read off the body the link is about to lower, so what is proven
            // is what runs. The environment is the one the body was judged in.
            if let rewritten = answer.procedure.block {
                try consumed(
                    rewritten,
                    at: symbol.place,
                    holding: declared.signature,
                    in: frame(for: symbol.origin)
                )
            }

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                let numbered = try row(of: symbol)

                try lowering.settle(numbered, body: rewritten, at: symbol.place)

                loweredRows.append(numbered)
            }

            return answer
        }

        // One document at a time, in the order each one's needs stand before
        // it. What a document reads of another is settled before it is read:
        // the documents it reaches stand behind it, and its own rows are the
        // stand-ins their refusal makes until it lowers them.
        for origin in gathered.standing {
            let module = modules[origin]
            let holding = held[origin] ?? []

            // The facts nobody declared. All three are fixed points over what
            // a body reaches, so a document's answer is settled once the
            // documents it reaches have theirs, and the standing refused a
            // ring where that is not so. Read over every declaration the
            // document holds rather than the reached ones: a path names a word
            // the call graph never mentions.
            pure(among: holding, settling: &settled, reading: moduleVariables)
            isolated(among: holding, settling: &isolatedDeclarations, in: gathered.space)
            failing(among: holding, settling: &failingDeclarations)

            // Where this document numbers its calls from: what it looks for
            // outside itself first, its own declarations after. Built from the
            // document alone, so a body lowers to the same numbers whatever
            // else the caller put in the link.
            let declared = holding.map(\.declared)
            let numbering = Numbering(
                imports: module.imports,
                walks: module.draft.walks,
                declared: declared,
                closures: module.draft.closures
            )
            let sending = Sending(numbering: numbering, pure: settled, isolated: isolatedDeclarations)

            declaredBy[origin] = declared
            orderedVariables[origin] = module.variables.keys.sorted()

            // This document's block of the table, in name order. What a
            // document declares is a run of rows rather than declarations
            // scattered through the table, so where its rows begin is a number
            // and its own are that number and an offset. A native answers as
            // it is from the start; a written body stands as the refusal it
            // would earn until it is lowered, so nothing folds through a body
            // half-made.
            lowering.hold(
                origin,
                standing: try holding.map { symbol in
                    Linked.standing(
                        label: symbol.declared,
                        origin: symbol.origin,
                        procedure: symbol.procedure,
                        pure: settled.contains(symbol.declared),
                        isolated: isolatedDeclarations.contains(symbol.declared),
                        failing: failingDeclarations[symbol.declared] ?? .unstated,
                        sends: try sending.rows(of: symbol.procedure, called: symbol.declared),
                        in: shapes
                    )
                },
                numbering: numbering,
                variables: orderedVariables[origin]
            )

            // Which declarations this document's paths may step to, read off
            // the rows it just laid down. A row is the declaration lowered,
            // and whether a path may reach one is a question about the slots
            // it lowered to.
            let words = try derivable(
                for: module,
                declaring: holding,
                among: gathered.space,
                pure: settled,
                answering: gathered.answering,
                reaching: lowering.rows,
                in: lowering.table
            )

            wordSymbols[origin] = words
            answeringWords[origin] = words.mapValues { symbol in symbol.procedure.signature }
            wordSpellings[origin] = words.reduce(into: [Name: [Name]]()) { spellings, entry in
                spellings[entry.value.declared, default: []].append(entry.key)
            }

            lowering.stepping(origin, to: words.compactMapValues { symbol in lowering.rows[symbol.declared] })

            named[origin] = Answered.answering(
                numbering,
                rows: lowering.rows,
                words: lowering.words[origin]
            )

            // The bodies the documents behind this one lowered, which this one
            // may run.
            foldable()

            // Settled after the words are known, because a constant may call
            // one: interpolation is `joined` now, and a constant that spells a
            // URL out of other constants is spelling it with words like any
            // other expression.
            let settledConstants = try self.constants(
                of: module,
                at: origin,
                folding: foldingTable(),
                writing: &lowering,
                in: frame(for: origin)
            )

            constants[origin] = settledConstants

            variables[origin] = try self.variables(
                of: module,
                at: origin,
                beside: settledConstants,
                folding: foldingTable(),
                writing: &lowering,
                in: frame(for: origin)
            )

            // What every declaration of this document whose `returns` nobody
            // wrote answers, read off its body.
            answers(
                of: holding.compactMap { symbol -> Unsaid? in
                    guard
                        symbol.procedure.signature.returns == nil,
                        let block = symbol.procedure.block
                    else { return nil }

                    return Unsaid(
                        symbol: symbol,
                        block: block,
                        environment: opening(symbol, of: symbol.procedure.signature),
                        sends: sent(in: block, reaching: wordSymbols[symbol.origin])
                    )
                },
                reading: frame,
                recording: { qualified, answer in
                    answered[qualified] = answer

                    for origin in wordSpellings.indices {
                        for spelling in wordSpellings[origin][qualified] ?? [] {
                            wordAnswered[origin][spelling] = answer
                        }
                    }
                }
            )

            // The words this document declared first, and only the words: they
            // are what every other body's folding executes, so they settle
            // before anything folds through them. Their own constant paths
            // meet the stand-ins (a word folding through a word is the circle
            // the stand-ins refuse) and that is a fact of each word's own text,
            // the same every link. Nothing else resolves here: checking a
            // word's calls does not resolve the callees, so whether a
            // declaration links stays a fact of its text rather than of who
            // happens to call it. In name order, so which mistake is reported
            // first is the text's fact too.
            for symbol in words.values.filter({ symbol in symbol.origin == origin })
                .sorted(by: { left, right in left.declared < right.declared }) {
                _ = try resolved(symbol)
            }

            foldable()

            // Every declaration this document makes, in name order, which is
            // the order its rows stand in. What a document says has to hold
            // whether or not this entry walks that way, so which declarations
            // are judged is not a question the entry answers.
            for symbol in holding {
                let (procedure, gathered) = try resolved(symbol)

                calls[symbol.declared] = gathered.map { call in call.callee.declared }

                // A constant answer is knowable from the text, so it is held to
                // the declaration here, the way a constant argument is. An
                // answer only a run can produce is settled at the boundary
                // instead.
                if let returns = procedure.signature.returns,
                   let answer = procedure.block?.result?.constantValue {
                    do {
                        _ = try returns.lowered(in: shapes).settling(answer, at: "answer", in: shapes)
                    } catch {
                        throw LinkError(
                            "answers \(answer.type), and its"
                                + " declaration promises \(returns): \(error)",
                            at: symbol.place.part(.result)
                        )
                    }
                }
            }
        }

        // The shapes the bodies stand on, written as each document's own
        // numbers. Lowering read this link's table to judge, so what it wrote
        // is this link's rows; what leaves compiling is the document's.
        let shaped = try lowering.numbered()

        // The rows as each document's own block: what it declared in name
        // order, then the closures its bodies lifted. The link lays the blocks
        // down and answers the names with where each began, so nothing about
        // where they sit leaves here.
        let judged = shaped.table.map(Judged.init)

        return Compiled(
            documents: modules.indices.map { origin in
                let declared = declaredBy[origin]

                return Compiled.Document(
                    document: .of(modules[origin]),
                    types: modules[origin].types,
                    constraints: modules[origin].constraints,
                    contracts: modules[origin].contracts,
                    declared: declared,
                    table: declared.compactMap { name in lowering.rows[name].map { row in judged[row] } }
                        + (lowering.closureRows[origin] ?? []).map { row in judged[row] },
                    calls: declared.map { name in calls[name] ?? [] },
                    words: wordSymbols[origin].mapValues { symbol in symbol.declared },
                    numbering: lowering.numbering[origin] ?? Numbering(imports: [], walks: [], declared: []),
                    shapeNumbering: shaped.numbering[origin] ?? ShapeNumbering(types: [], memberships: []),
                    variables: orderedVariables[origin].map { name in
                        (name: name, value: variables[origin]?[name] ?? .null)
                    }
                )
            },
            standing: gathered.standing
        )
    }

    // Which row a run starts from, and which declarations it reaches. Nothing
    // is judged and nothing runs: every declaration stands judged already, and
    // the answer is read off the call graph the judgment gathered.
    func link(_ compiled: Compiled, entry: Name) throws -> Image {
        // Every document's block laid down, which is where its rows first
        // stand somewhere. What a name reaches is answered from here on.
        let assembled = compiled.assembled()

        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it.
        guard let start = assembled.rows[entry] else {
            throw LinkError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(assembled.rows.keys.sorted().map(\.spelling).joined(separator: ", "))",
                at: nil
            )
        }

        var reached: Set<Name> = []
        var frontier: [Name] = [entry]
        var index = 0

        while index < frontier.count {
            let declared = frontier[index]
            index += 1

            guard reached.insert(declared).inserted else { continue }
            guard let row = assembled.rows[declared] else { continue }

            frontier.append(contentsOf: assembled.calls[row])
        }

        // The shapes of this link, made from what its documents declared and
        // laid down in the order their blocks are. Which types answer which
        // contracts is read across the documents, so the rows a body stands on
        // are answered here rather than carried out of a compile.
        let declared = try declared(in: compiled.documents)
        let types = try shaped(
            self.types(
                declared: declared.types,
                constraints: declared.constraints,
                contracts: declared.contracts,
                of: compiled.documents,
                standing: compiled.standing,
                numbered: Linkage()
            ),
            types: declared.types,
            contracts: declared.contracts,
            among: assembled.rows.reduce(into: [Name: Declared<Signature>]()) { table, entry in
                let row = assembled.table[entry.value]

                table[entry.key] = Declared(
                    row.signature,
                    at: .procedure(entry.key.spelling, in: compiled.documents[row.origin].document),
                    of: row.origin
                )
            }
        ).types

        // The documents' own numbers turned into this link's rows, and the
        // calls through a contract filled with the rows that answer them.
        let relocating = Relocating(assembled, types: types)
        let linked = try relocating.linked()

        return Image(
            linked: linked.table,
            start: start,
            rows: assembled.rows,
            reached: reached,
            types: types,
            variables: try relocating.started(assembled.variables)
        )
    }

    // MARK: - Private
}
