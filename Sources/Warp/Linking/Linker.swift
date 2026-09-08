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
// A link is handed its whole world at once. The words a program can call are
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
    // What to link is the caller's statement (the whole world at once) and
    // `entry` names which declaration this run starts from. There is no
    // default: guessing which procedure was meant would be an opinion nobody
    // gave.
    //
    // A bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func link(_ modules: [Module], entry: Name) throws -> Image {
        try link(compile(modules), entry: entry)
    }

    // MARK: - Internal
    // Everything the documents settle on their own. No entry reaches in here:
    // what a document says has to hold whichever declaration a run starts
    // from.
    func compile(_ modules: [Module]) throws -> Compiled {
        // Type and constraint declarations first, because everything after
        // this reads type expressions against them. The qualifying pass owns
        // their uniqueness, so it hands over the tables that fact was proved on.
        try once(modules)

        let (declaredTypes, declaredConstraints, declaredContracts) = try declared(in: modules)

        let symbols = try self.symbols(of: modules)

        // The order each document's needs stand before it, which is the order
        // the facts nobody declared are read in and the order the rows stand
        // in. A ring is refused here.
        //
        // After the declarations are held to being declared once. Standing
        // reads a name as whichever document declared it, and where two
        // declare one name that reading is arbitrary: it can put a document
        // in its own reach and call the pair a ring. The doubled name is the
        // defect, so it is the refusal an author gets.
        let world = try World(modules)

        // Where each document stands, by where the caller put it. Everything a
        // link builds is keyed by the caller's position, and the rows follow
        // the standing, so this is what turns one into the other.
        var rank = [Int](repeating: 0, count: modules.count)

        for (place, position) in world.standing.enumerated() {
            rank[position] = place
        }

        // A document's types take a run of shape rows the way its declarations
        // take a run of table rows, in the standing order, so a document's
        // shapes are behind the shapes it names.
        let declaring = try self.types(
            of: modules,
            declared: declaredTypes,
            constraints: declaredConstraints,
            contracts: declaredContracts,
            standing: world.standing.flatMap { position in modules[position].types.keys.sorted() }
        )

        // Every declaration under its declared spelling. The spellings are
        // unique, since the symbol gathering refused a double, and every call
        // in every body asks this table.
        let space = symbols.reduce(into: [Name: Symbol]()) { table, symbol in
            table[symbol.declared] = symbol
        }

        // Which types answer which contracts. Read off the declarations, so it
        // is worked out here rather than where the types were declared, and
        // the table is remade holding it. The rows are numbered from the
        // declarations alone, so a shape lowered against either table is the
        // same shape.
        let witnessed = try witnesses(
            of: declaredContracts,
            over: declaredTypes,
            among: space,
            in: declaring
        )
        let types = declaring.satisfying(witnessed.mapValues { answering in Set(answering.keys) })

        // Every judgment the link asks and every row it builds reads the
        // table the run will read.
        let shapes = types.shapes

        // The spelling a call writes to reach a contract's word: the
        // contract's name and the word's, with a dot between them. Built here
        // once, so nothing downstream takes a name apart again.
        let contractWords = declaredContracts.reduce(into: [Name: ContractWord]()) { table, entry in
            for (word, signature) in entry.value.held {
                let spelling = Name(normal: "\(entry.key.spelling).\(word.spelling)")

                table[spelling] = ContractWord(
                    contract: entry.key,
                    word: word,
                    signature: signature,
                    slots: signature.lowered(in: shapes),
                    answers: signature.returns?.lowered(in: shapes),
                    answering: (witnessed[entry.key] ?? [:]).compactMapValues { words in words[word] }
                )
            }
        }

        // A contract's word and a declaration cannot take one spelling. A call
        // writing it lowers to the pick the contract makes, so the declaration
        // standing under it is reachable by nothing and the two readings of
        // one name never meet.
        //
        // In name order, so which collision is reported first is the text's
        // fact rather than a hash seed's.
        if
            let spelling = contractWords.keys.sorted().first(where: { taken in space[taken] != nil }),
            let declared = space[spelling],
            let asked = contractWords[spelling]
        {
            throw LinkError(
                "'\(spelling)' is declared by \(declared.spelled) and asked as a word"
                    + " of '\(asked.contract)', so there is no answer to which one a"
                    + " call reaches. A contract's word and a declaration cannot take"
                    + " one spelling",
                at: declared.place
            )
        }

        // What every declaration returns, by the name a resolved call site
        // uses. Built before the walk so a call can be judged against a callee
        // the walk has not reached yet.
        let signatures = symbols.reduce(into: [Name: Signature]()) { table, symbol in
            table[symbol.declared] = symbol.procedure.signature
        }

        // Purity is worked out over every declaration rather than the reached
        // ones: a path names a word the call graph never mentions.
        let moduleVariables = modules.enumerated().reduce(into: [Int: Set<Name>]()) { table, entry in
            table[entry.offset] = Set(entry.element.variables.keys)
        }

        // One document at a time, in the order each one's needs stand before
        // it. All three are fixed points over what a body reaches, so a
        // document's answer is settled once the documents it reaches have
        // theirs, and the standing refused a ring where that is not so. Read
        // over every declaration a document holds rather than the reached
        // ones: a path names a word the call graph never mentions.
        let held = symbols.reduce(into: [Int: [Symbol]]()) { table, symbol in
            table[symbol.origin, default: []].append(symbol)
        }

        var settled: Set<Name> = []
        var isolatedDeclarations: Set<Name> = []
        var failingDeclarations: [Name: Failing] = [:]

        for position in world.standing {
            let holding = held[position] ?? []

            pure(among: holding, settling: &settled, reading: moduleVariables)
            isolated(among: holding, settling: &isolatedDeclarations, signatures: signatures)
            failing(among: holding, settling: &failingDeclarations)
        }

        // The table a run reads, one row per declaration. A native answers as
        // it is from the start; a written body stands as the refusal it would
        // earn until it is lowered, so nothing folds through a body half-made.
        var rows: [Name: Int] = [:]
        var table: [Linked] = []

        // A document's declarations take a run of rows, in the order the
        // documents stand and in name order inside each. What a document
        // declares is then a block of the table rather than declarations
        // scattered through it, so where a document's rows begin is a number
        // and its own rows are that number and an offset. In the standing
        // order, so a document's rows are behind the rows it reaches.
        //
        // The spellings first, so a native word's sends reach a row whatever
        // order the declarations stand in.
        let declarations = symbols.sorted { left, right in
            (rank[left.origin], left.declared) < (rank[right.origin], right.declared)
        }

        for (position, symbol) in declarations.enumerated() {
            rows[symbol.declared] = position
        }

        // What each document declares, in the order the declarations stand.
        // Read off in one pass rather than by asking the declarations for a
        // document's own each time a document asks: the answer is the same
        // walk either way, and asking once per document walks the world once
        // per document.
        let declaredBy = declarations.reduce(into: [Int: [Name]]()) { table, symbol in
            table[symbol.origin, default: []].append(symbol.declared)
        }

        // Where each document numbers its calls from: what it looks for
        // outside itself first, its own declarations after. Built from the
        // documents alone, so a body lowers to the same numbers whatever else
        // the caller put in the link.
        let numbering = modules.enumerated().reduce(into: [Int: Numbering]()) { table, entry in
            table[entry.offset] = Numbering(
                imports: entry.element.imports,
                walks: entry.element.draft.walks,
                declared: declaredBy[entry.offset] ?? []
            )
        }

        let sending = numbering.mapValues { held in
            Sending(numbering: held, pure: settled, isolated: isolatedDeclarations)
        }

        for symbol in declarations {
            table.append(
                Linked.standing(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    pure: settled.contains(symbol.declared),
                    isolated: isolatedDeclarations.contains(symbol.declared),
                    failing: failingDeclarations[symbol.declared] ?? .unstated,
                    sends: try sending[symbol.origin]?.rows(
                        of: symbol.procedure,
                        called: symbol.declared
                    ) ?? [],
                    in: shapes
                )
            )
        }

        // Which declarations a path segment may reach, read off the rows the
        // link just made. A row is the declaration lowered, and whether a path
        // may reach one is a question about the slots it lowered to.
        let wordSymbols = try derivable(
            among: symbols,
            pure: settled,
            answering: Set(witnessed.values.flatMap { answering in answering.values.flatMap(\.values) }),
            reaching: rows,
            in: table
        )

        // What the link read off a body whose declaration wrote no `returns`.
        // Only those: what a declaration wrote is on its row already, and a
        // table holding every spelling would hash every declared name to say
        // what the row says.
        var answered: [Name: Shape] = [:]
        var wordAnswered: [Name: Shape] = [:]

        // The tables as the author spelled them, and the form the link's own
        // settling reads: a written body is swapped for the refusal it would
        // earn, because it is itself still being resolved beside the constants
        // it may read. The table carries the fact, so no resolver needs a flag
        // saying when it runs. Selectors and path words are two tables, because
        // they are two questions: what a selector reaches, and what a bare
        // spelling a walk writes may call. One table masked by a set let one
        // spelling answer with the other question's declaration.
        //
        // Both are filled with the answers read off bodies whose declaration
        // wrote none, and both by the same reading. A spelling that answers one
        // way through a call and another through a path would be one
        // declaration saying two things.
        let answeringSignatures = signatures
        let answeringWords = wordSymbols.mapValues { symbol in symbol.procedure.signature }

        // Which spellings a path reaches one declaration by. A word may be
        // reachable under more than one, and an answer worked out for it is
        // that declaration's however a walk spelled it.
        let wordSpellings = wordSymbols.reduce(into: [Name: [Name]]()) { spellings, entry in
            spellings[entry.value.declared, default: []].append(entry.key)
        }

        // Which row a path reaches under each spelling, so what a word takes
        // and answers is read off the row rather than lowered again.
        let wordRows = wordSymbols.compactMapValues { symbol in rows[symbol.declared] }

        // Each document's variables in the order a run makes their boxes,
        // decided here once: the layouts read positions from it and the
        // image carries the starting values in it.
        let orderedVariables = modules.enumerated().reduce(into: [Int: [Name]]()) { table, entry in
            table[entry.offset] = entry.element.variables.keys.sorted()
        }

        var lowering = Lowering(
            table: table,
            rows: rows,
            words: wordRows,
            numbering: numbering,
            variables: orderedVariables.mapValues { names in
                names.enumerated().reduce(into: [:]) { positions, variable in positions[variable.element] = variable.offset }
            },
            contractWords: contractWords,
            shapes: shapes
        )

        // What a body's constant paths fold against. The stand-ins, while
        // the words themselves settle: a word folding through a word would
        // be a circle, and which words are already lowered is a fact of
        // name order rather than of the text. Once the words are resolved,
        // folding runs them.
        var foldingTable = Answered.documents(
            table,
            rows: rows,
            words: wordRows,
            numbering: numbering
        )

        func row(of symbol: Symbol) throws -> Int {
            guard let row = rows[symbol.declared] else {
                throw LinkError("'\(symbol.declared)' has no row in the table", at: symbol.place)
            }

            return row
        }

        func frame() -> TypeFrame {
            TypeFrame(
                symbols: space,
                signatures: answeringSignatures,
                types: types,
                linked: table,
                rows: rows,
                answers: answered,
                words: answeringWords,
                wordRows: wordRows,
                wordAnswers: wordAnswered,
                pure: settled,
                isolated: isolatedDeclarations,
                failing: failingDeclarations,
                contractWords: contractWords,
                variables: moduleVariables
            )
        }

        let declaredFrame = frame()

        // Settled after the words are known, because a constant may call one:
        // interpolation is `joined` now, and a constant that spells a URL out of
        // other constants is spelling it with words like any other expression.
        let constants = try self.constants(
            of: modules,
            folding: foldingTable,
            with: declaredFrame
        )

        let variables = try self.variables(
            of: modules,
            beside: constants,
            folding: foldingTable,
            with: declaredFrame
        )

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

        // What every declaration whose `returns` nobody wrote answers, read
        // off its body.
        answers(
            of: symbols.compactMap { symbol -> Unsaid? in
                guard
                    symbol.procedure.signature.returns == nil,
                    let block = symbol.procedure.block
                else { return nil }

                return Unsaid(
                    symbol: symbol,
                    block: block,
                    environment: opening(symbol, of: symbol.procedure.signature),
                    sends: sent(in: block, reaching: wordSymbols)
                )
            },
            reading: frame,
            recording: { qualified, answer in
                answered[qualified] = answer

                for spelling in wordSpellings[qualified] ?? [] {
                    wordAnswered[spelling] = answer
                }
            }
        )

        let frame = frame()

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
                    in: foldingTable,
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
                    with: frame,
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

            try checked(answer.calls, in: frame)

            // Read off the body the link is about to lower, so what is proven
            // is what runs. The environment is the one the body was judged in.
            if let rewritten = answer.procedure.block {
                try consumed(
                    rewritten,
                    at: symbol.place,
                    holding: declared.signature,
                    in: frame
                )
            }

            // Lowered once every call in it passed the gate, so nothing
            // the gate refuses reaches the lowering.
            if let rewritten = answer.procedure.block {
                try lowering.settle(try row(of: symbol), body: rewritten, at: symbol.place)
            }

            return answer
        }

        // The words first, and only the words: they are what every other body's
        // folding executes, so they settle before anything folds through them.
        // Their own constant paths meet the stand-ins (a word folding through a
        // word is the circle the stand-ins refuse) and that is a fact of each
        // word's own text, the same every link. Nothing else resolves here:
        // checking a word's calls does not resolve the callees, so no other
        // declaration is ever folded against the stand-ins, and whether a
        // declaration links stays a fact of its text rather than of who happens
        // to call it. In the order the rows stand, so which mistake is
        // reported first is the text's fact too.
        for symbol in wordSymbols.values.sorted(by: { left, right in
            (rank[left.origin], left.declared) < (rank[right.origin], right.declared)
        }) {
            _ = try resolved(symbol)
        }

        foldingTable = foldingTable.holding(lowering.table)

        // Every declaration, one document at a time in the order they stand
        // and in name order inside each, which is the order their rows stand
        // in. What a document says has to hold whether or not this entry walks
        // that way, so which declarations are judged is not a question the
        // entry answers, and a document is judged after the documents it
        // reaches rather than wherever its spellings fall among theirs.
        var calls: [Name: [Name]] = [:]

        for symbol in declarations {
            let (procedure, gathered) = try resolved(symbol)

            calls[symbol.declared] = gathered.map { call in call.callee.declared }

            // A constant answer is knowable from the text, so it is held to the
            // declaration here, the way a constant argument is. An answer only
            // a run can produce is settled at the boundary instead.
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

        // The shapes the bodies stand on, written as each document's own
        // numbers. Lowering read this link's table to judge, so what it wrote
        // is this link's rows; what leaves compiling is the document's.
        let shaped = try lowering.numbered()

        return Compiled(
            table: shaped.table,
            rows: rows,
            words: wordRows,
            calls: calls,
            types: types,
            contractWords: contractWords,
            numbering: numbering,
            shapeNumbering: shaped.numbering,
            variables: variables.reduce(into: [:]) { table, entry in
                table[entry.key] = (orderedVariables[entry.key] ?? []).map { name in
                    (name: name, value: entry.value[name] ?? .null)
                }
            }
        )
    }

    // Which row a run starts from, and which declarations it reaches. Nothing
    // is judged and nothing runs: every declaration stands judged already, and
    // the answer is read off the call graph the judgment gathered.
    func link(_ compiled: Compiled, entry: Name) throws -> Image {
        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it.
        guard let start = compiled.rows[entry] else {
            throw LinkError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(compiled.rows.keys.sorted().map(\.spelling).joined(separator: ", "))",
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

            frontier.append(contentsOf: compiled.calls[declared] ?? [])
        }

        // The documents' own numbers turned into this link's rows, and the
        // calls through a contract filled with the rows that answer them.
        let linked = try Relocating(compiled).linked()

        return Image(
            linked: linked.table,
            start: start,
            rows: compiled.rows,
            reached: reached,
            types: compiled.types,
            variables: compiled.variables
        )
    }

    // MARK: - Private
}
