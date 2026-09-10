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
    func compile(_ modules: [Module], in gathered: Gathered) throws -> [Compiled] {
        // What each document declares, in name order, which is the order its
        // rows stand in.
        let held = gathered.symbols.reduce(into: [Int: [Symbol]]()) { table, symbol in
            table[symbol.origin, default: []].append(symbol)
        }

        var compiling = Compiling(
            gathered,
            naming: modules.map { module in Place.Document.of(module) }
        )

        // One document at a time, in the order each one's needs stand before
        // it. What a document reads of another is settled before it is read:
        // the documents it reaches stand behind it, and its own rows are the
        // stand-ins their refusal makes until it lowers them.
        let compiled = try gathered.standing.map { origin in
            try compile(modules[origin], at: origin, declaring: held[origin] ?? [], in: &compiling)
        }

        // Back in the order the documents were handed over. The standing says
        // which one to compile next and nothing about which one this is.
        var ordered = compiled

        for (position, origin) in gathered.standing.enumerated() {
            ordered[origin] = compiled[position]
        }

        return ordered
    }

    // One document compiled against documents already compiled, which is what
    // a caller holding a cache of them has.
    //
    // The order is the caller's statement: what is handed over stands before
    // this document, in the order it was handed over. A compile of the whole
    // graph works that order out from the imports and refuses a ring; here it
    // arrives already worked out, and a caller that hands over the wrong order
    // is handing over a document that was never compiled against these.
    //
    // What the list answers is read again, since the shape spaces of a link
    // are its documents' together and this document was not in the ones the
    // others were compiled against.
    func compile(_ module: Module, against compiled: [Compiled]) throws -> Compiled {
        let origin = compiled.count
        let documents: [any Declaring] = compiled + [module]
        let declared = try declared(in: documents)

        let declaring = try types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: documents,
            standing: Array(documents.indices),
            numbered: Linkage()
        )

        try judge([module], in: declaring)

        // Every declaration this document is compiled beside, by the spelling
        // it was declared by: what the documents behind it left on their rows,
        // and what it wrote itself. A name two of them declare is refused
        // here, for the same reason two `.c` files cannot both define a
        // symbol.
        //
        // Refused rather than taken as the caller's statement, which the order
        // is: a doubled spelling is not a question of which document to read
        // first, it is a table with no answer for that name. A ring and a
        // document handed over twice are the order's, and this is handed an
        // order that was worked out already.
        var signatures: [Name: Declared<Signature>] = [:]

        for (position, document) in compiled.enumerated() {
            for (offset, name) in document.declared.enumerated() {
                signatures[name] = Declared(
                    document.table[offset].signature,
                    at: .procedure(name.spelling, in: document.document),
                    of: position
                )
            }
        }

        let symbols = try self.symbols(of: [module]).map { symbol in
            Symbol(
                declared: symbol.declared,
                document: symbol.document,
                origin: origin,
                procedure: symbol.procedure
            )
        }

        for symbol in symbols {
            if let first = signatures[symbol.declared] {
                throw LinkError(
                    "'\(symbol.declared)' is declared by \(first.spelled), which this"
                        + " document is compiled against, and by \(symbol.spelled)."
                        + " Two declarations of a name have no way to be told apart",
                    at: symbol.place
                )
            }

            signatures[symbol.declared] = Declared(
                symbol.procedure.signature,
                at: symbol.place,
                of: origin
            )
        }

        let shaped = try self.shaped(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            among: signatures
        )

        var compiling = try Compiling(
            compiled,
            types: shaped.types,
            contractWords: shaped.contractWords,
            answering: shaped.answering,
            naming: documents.map(\.document)
        )

        return try compile(module, at: origin, declaring: symbols, in: &compiling)
    }

    // One document compiled against what stands before it, and what it proves
    // written into that. Its own rows stand as the refusal they would earn
    // until it lowers them, so a word folding through a word is refused as the
    // circle it is.
    func compile(
        _ module: Module,
        at origin: Int,
        declaring holding: [Symbol],
        in compiling: inout Compiling
    ) throws -> Compiled {
        let shapes = compiling.shapes

        compiling.begin()

        // What this document declares and what its variables are called, in
        // the order the rows and the boxes stand in.
        let declared = holding.map(\.declared)
        let boxes = module.variables.keys.sorted()
        let reading = Set(module.variables.keys)

        // What the link read off this document's bodies whose declarations
        // wrote no `returns`, and which declaration each bare spelling its
        // paths step to reaches.
        var read: [Name: Shape] = [:]
        var reached: [Name: Name] = [:]

        // What this document settled, and what each of its declarations calls.
        var constants: [Name: Value] = [:]
        var variables: [Name: Value] = [:]
        var calls: [Name: [Name]] = [:]

        // One document's reading. What a path may walk to is the document's
        // own, so the frame is made for the document being read.
        func frame() -> TypeFrame {
            compiling.frame(stepping: reached, reading: reading)
        }

        func row(of symbol: Symbol) throws -> Int {
            guard let row = compiling.lowering.rows[symbol.declared] else {
                throw LinkError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        // The names in scope before a body's first statement: its parameters,
        // the constants its module declared beside them, and the variables. A
        // variable stands in the environment as a box whose type is fixed:
        // what a write puts in it has to fit what it started as, because every
        // body of the document reads it as that.
        func opening(_ signature: Signature) -> [Name: Shape] {
            environment(of: signature, in: shapes)
                .merging(constants.mapValues { value in type(of: value, in: shapes) }) { _, constant in
                    constant
                }
                .merging(
                    variables.mapValues { value in .inout(type(of: value, in: shapes)) }
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

            let declaration = symbol.procedure

            var answer = (procedure: declaration, calls: [CallSite]())

            if let block = declaration.block {
                // A body not yet lowered stands as its refusal, so a word
                // folding through a word is refused as the circle it is.
                let folding = Folding(
                    constants: constants,
                    origin: origin,
                    in: compiling.folding(),
                    shapes: shapes
                )

                // The starting environment knows the constants beside the
                // parameters, so a constant-headed path is judged against the
                // type of the value it will fold to.
                let (rewritten, gathered) = try resolvedSites(
                    in: block,
                    at: symbol.place,
                    in: opening(declaration.signature),
                    with: frame(),
                    folding: folding,
                    origin: origin
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

            try checked(answer.calls, in: frame())

            // Read off the body the link is about to lower, so what is proven
            // is what runs. The environment is the one the body was judged in.
            if let rewritten = answer.procedure.block {
                try consumed(
                    rewritten,
                    at: symbol.place,
                    holding: declaration.signature,
                    in: frame()
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
        // than the reached ones: a path names a word the call graph never
        // mentions.
        //
        // What this document declares, by the spelling a call in it writes.
        // Its own rows do not stand yet, and this is what says what they take
        // until they do.
        let own = holding.reduce(into: [Name: Signature]()) { asked, symbol in
            asked[symbol.declared] = symbol.procedure.signature
        }

        pure(among: holding, settling: &compiling.pure, reading: reading)
        isolated(
            among: holding,
            settling: &compiling.isolated,
            taking: { [rows = compiling.lowering.rows, table = compiling.lowering.table] selector in
                own[selector] ?? rows[selector].map { row in table[row].signature }
            }
        )
        failing(among: holding, settling: &compiling.failing)

        // Where this document numbers its calls from: what it looks for
        // outside itself first, its own declarations after. Built from the
        // document alone, so a body lowers to the same numbers whatever
        // else the caller put in the link.
        let numbering = Numbering(
            imports: module.imports,
            walks: module.draft.walks,
            declared: declared,
            closures: module.draft.closures
        )
        let sending = Sending(
            numbering: numbering,
            pure: compiling.pure,
            isolated: compiling.isolated
        )

        // This document's block of the table, in name order. What a
        // document declares is a run of rows rather than declarations
        // scattered through the table, so where its rows begin is a number
        // and its own are that number and an offset. A native answers as
        // it is from the start; a written body stands as the refusal it
        // would earn until it is lowered, so nothing folds through a body
        // half-made.
        compiling.hold(
            origin,
            standing: try holding.map { symbol in
                Linked.standing(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    pure: compiling.pure.contains(symbol.declared),
                    isolated: compiling.isolated.contains(symbol.declared),
                    failing: compiling.failing[symbol.declared] ?? .unstated,
                    sends: try sending.rows(of: symbol.procedure, called: symbol.declared),
                    in: shapes
                )
            },
            numbering: numbering,
            variables: boxes
        )

        // Which declarations this document's paths may step to, read off
        // the rows it just laid down. A row is the declaration lowered,
        // and whether a path may reach one is a question about the slots
        // it lowered to.
        let words = try derivable(
            for: module,
            declaring: declared,
            naming: compiling.documents,
            pure: compiling.pure,
            answering: compiling.answering,
            reaching: compiling.lowering.rows,
            in: compiling.lowering.table
        )

        reached = words

        compiling.steps(origin, to: words.compactMapValues { declared in compiling.lowering.rows[declared] })

        // The bodies the documents behind this one lowered, which this one
        // may run.
        compiling.foldable()

        // Settled after the words are known, because a constant may call
        // one: interpolation is `joined` now, and a constant that spells a
        // URL out of other constants is spelling it with words like any
        // other expression.
        //
        // The frame is read before the lowering is handed over, since one of
        // the tables a frame stands on is the lowering this writes into.
        constants = try self.constants(
            of: module,
            at: origin,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            in: frame()
        )

        variables = try self.variables(
            of: module,
            at: origin,
            beside: constants,
            folding: compiling.folding(),
            writing: &compiling.lowering,
            in: frame()
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
                    environment: opening(symbol.procedure.signature),
                    sends: sent(in: block, reaching: words)
                )
            },
            reading: frame,
            recording: { qualified, answer in
                read[qualified] = answer

                compiling.read(answer, as: qualified, of: origin)
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
        let stepped = Set(words.values)

        for symbol in holding where stepped.contains(symbol.declared) {
            _ = try resolved(symbol)
        }

        compiling.foldable()

        // Every declaration this document makes, in name order, which is
        // the order its rows stand in. What a document says has to hold
        // whether or not this entry walks that way, so which declarations
        // are judged is not a question the entry answers.
        for symbol in holding {
            let (procedure, gathered) = try resolved(symbol)

            calls[symbol.declared] = gathered.map { call in call.callee }

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

        // The shapes its bodies stand on, written as this document's own
        // numbers. Lowering read the link's table to judge, so what it wrote
        // is that link's rows; what leaves here is the document's.
        //
        // Its rows are its declarations in name order, then the closures its
        // bodies lifted, in the order it numbers them.
        let shaped = try compiling.lowering.numbered(
            declared.compactMap { name in compiling.lowering.rows[name] }
                + (compiling.lowering.closureRows[origin] ?? []),
            of: origin,
            answering: read
        )

        return Compiled(
            document: .of(module),
            types: module.types,
            constraints: module.constraints,
            contracts: module.contracts,
            claiming: module.claiming,
            requiring: compiling.requiring.claims,
            declared: declared,
            table: shaped.table.map(Judged.init),
            calls: declared.map { name in calls[name] ?? [] },
            answers: shaped.answers,
            words: words,
            numbering: numbering,
            shapeNumbering: shaped.numbering,
            variables: boxes.map { name in (name: name, value: variables[name] ?? .null) }
        )
    }

    // Which row a run starts from, and which declarations it reaches. Nothing
    // is judged and nothing runs: every declaration stands judged already, and
    // the answer is read off the call graph the judgment gathered.
    func link(_ compiled: [Compiled], entry: Name) throws -> Image {
        // Every document's block laid down, which is where its rows first
        // stand somewhere. What a name reaches is answered from here on.
        let assembled = Assembled(compiled)

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
        let declared = try declared(in: compiled)
        let declaring = try self.types(
            declared: declared.types,
            constraints: declared.constraints,
            contracts: declared.contracts,
            of: compiled,
            standing: Array(compiled.indices),
            numbered: Linkage()
        )
        let signatures = assembled.rows.reduce(into: [Name: Declared<Signature>]()) { table, entry in
            let origin = assembled.origins[entry.value]

            table[entry.key] = Declared(
                assembled.table[entry.value].signature,
                at: .procedure(entry.key.spelling, in: compiled[origin].document),
                of: origin
            )
        }

        // The other place the whole list is in hand. A document compiled
        // against part of one was never asked to answer for a claim the rest
        // of the list backs, so this is where every claim is held to it.
        try backing(
            declared.claims,
            asking: declared.contracts,
            over: declared.types,
            among: signatures,
            in: declaring
        )

        let types = try shaped(
            declaring,
            claims: declared.claims,
            contracts: declared.contracts,
            among: signatures
        ).types

        // What each document leaned on, answered by every claim in the list.
        // A compile wrote these down rather than judging them, since a claim
        // it never named may be what answers.
        for document in compiled {
            try leaning(
                document.requiring,
                on: types.shapes.satisfying,
                of: document.document
            )
        }

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
