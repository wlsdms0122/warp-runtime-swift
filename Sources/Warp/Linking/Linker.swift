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
// Unreached code is checked too. A misspelled procedure in an arm today's
// arguments never take is a defect whether or not this run walks that way, so
// linking follows the whole call graph and refuses on the first name it cannot
// resolve rather than on the first one a run happens to reach.
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
// value at load has nothing left to do at run time, so linking folds it into
// the literal it always was.
//
// What it can promise is narrower than "nothing unresolved remains": arguments
// are mostly references that settle at run time, so this checks names, arity and
// the types of *constant* arguments. Calling a value is outside the promise
// entirely, because a closure's callee is a run-time fact.
//
// What `link` does it does in four stages, each in a file of its own beside
// this one: resolving (`Linker+Resolving`), the facts nobody declared
// (`Linker+Deriving`, `Linker+Isolating`), judging (`Linker+Judging`,
// `Linker+Typing`) and lowering (`Lowering`).
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
        // Type and constraint declarations first, because everything after
        // this reads type expressions against them. The qualifying pass owns
        // their uniqueness, so it hands over the tables that fact was proved on.
        try once(modules)

        let (declaredTypes, declaredConstraints, declaredContracts) = try declared(in: modules)

        let declaring = try self.types(
            of: modules,
            declared: declaredTypes,
            constraints: declaredConstraints,
            contracts: declaredContracts
        )

        let symbols = try self.symbols(of: modules)

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
                    answering: (witnessed[entry.key] ?? [:]).compactMapValues { words in words[word] }
                )
            }
        }

        // Every judgment the link asks and every row it builds reads the
        // table the run will read.
        let shapes = types.shapes

        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it.
        guard let start = space[entry] else {
            throw LinkError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(symbols.map(\.declared).sorted().map(\.spelling).joined(separator: ", "))",
                at: nil
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
        let settled = pure(among: symbols, reading: moduleVariables)
        let (selectorSymbols, wordSymbols) = try derivable(
            among: symbols,
            pure: settled,
            answering: Set(witnessed.values.flatMap { answering in answering.values.flatMap(\.values) }),
            in: shapes
        )

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
        var answeringSignatures = signatures
        var answeringWords = wordSymbols.mapValues { symbol in symbol.procedure.signature }

        // Which spellings a path reaches one declaration by. A word may be
        // reachable under more than one, and an answer worked out for it is
        // that declaration's however a walk spelled it.
        let wordSpellings = wordSymbols.reduce(into: [Name: [Name]]()) { spellings, entry in
            spellings[entry.value.declared, default: []].append(entry.key)
        }

        let isolatedDeclarations = isolated(among: symbols, signatures: signatures)
        let failingDeclarations = failing(among: symbols)

        // The table a run reads, one row per declaration in name order. A
        // native answers as it is from the start; a written body stands as
        // the refusal it would earn until it is lowered, so nothing folds
        // through a body half-made.
        var rows: [Name: Int] = [:]
        var table: [Linked] = []

        for symbol in symbols.sorted(by: { $0.declared < $1.declared }) {
            rows[symbol.declared] = table.count
            table.append(
                Linked.standing(
                    label: symbol.declared,
                    origin: symbol.origin,
                    procedure: symbol.procedure,
                    pure: settled.contains(symbol.declared),
                    isolated: isolatedDeclarations.contains(symbol.declared),
                    failing: failingDeclarations[symbol.declared] ?? .unstated,
                    in: shapes
                )
            )
        }

        // Each document's variables in the order a run makes their boxes,
        // decided here once: the layouts read positions from it and the
        // image carries the starting values in it.
        let orderedVariables = modules.enumerated().reduce(into: [Int: [Name]]()) { table, entry in
            table[entry.offset] = entry.element.variables.keys.sorted()
        }

        var lowering = Lowering(
            table: table,
            rows: rows,
            words: wordSymbols.compactMapValues { symbol in rows[symbol.declared] },
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
        var foldingTable = table

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
                words: answeringWords,
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
            lowering: lowering,
            in: types,
            with: declaredFrame
        )

        let variables = try self.variables(
            of: modules,
            beside: constants,
            lowering: lowering,
            in: types,
            with: declaredFrame
        )

        // The names in scope before a body's first statement: its parameters,
        // the constants its module declared beside them, and the variables. A
        // variable stands in the environment as a box whose type is fixed:
        // what a write puts in it has to fit what it started as, because every
        // body of the document reads it as that.
        func opening(_ symbol: Symbol, of signature: Signature) -> [Name: TypeExpression] {
            environment(of: signature)
                .merging(
                    (constants[symbol.origin] ?? [:]).mapValues { value in type(of: value) }
                ) { _, constant in constant }
                .merging(
                    (variables[symbol.origin] ?? [:]).mapValues { value in .inout(type(of: value)) }
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
                answeringSignatures[qualified] = answeringSignatures[qualified]?
                    .answering(answer)

                for spelling in wordSpellings[qualified] ?? [] {
                    answeringWords[spelling] = answeringWords[spelling]?.answering(answer)
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
                    table: foldingTable,
                    rows: lowering.rows,
                    words: lowering.words,
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
        // to call it. In name order, so which mistake is reported first is the
        // text's fact too.
        for (_, symbol) in wordSymbols.sorted { $0.key < $1.key } {
            _ = try resolved(symbol)
        }

        foldingTable = lowering.table

        var procedures: [Name: Procedure] = [:]
        var frontier: [Symbol] = [start]
        var index = 0
        var linked: Procedure?

        // Breadth over the frontier, so the first refusal an author sees is the
        // first mistake they wrote. Memoising by declared spelling is what makes a
        // recursive procedure link once instead of forever.
        while index < frontier.count {
            let symbol = frontier[index]
            index += 1

            if procedures[symbol.declared] != nil { continue }

            let (resolved, calls) = try resolved(symbol)

            procedures[symbol.declared] = resolved

            if symbol.declared == start.declared { linked = resolved }

            // A constant answer is knowable from the text, so it is held to the
            // declaration here, the way a constant argument is. An answer only
            // a run can produce is settled at the boundary instead.
            if let returns = resolved.signature.returns,
               let answer = resolved.block?.result?.constantValue {
                do {
                    _ = try returns.settling(answer, at: "answer", in: shapes)
                } catch {
                    throw LinkError(
                        "answers \(answer.type), and its"
                            + " declaration promises \(returns): \(error)",
                        at: symbol.place.slot(.result)
                    )
                }
            }

            for call in calls {
                frontier.append(call.callee)
            }
        }

        // Every pure body compiles and has its sends checked, reached or not.
        // The same promise the frontier makes for the call graph. After the
        // frontier on purpose, so a mistake on a path from the entry is
        // reported before one in a declaration nothing reaches; in name order,
        // so which unreached mistake comes first is a fact of the text rather
        // than of a hash seed.
        for (_, symbol) in selectorSymbols.sorted { $0.key < $1.key } {
            _ = try resolved(symbol)
        }

        return Image(
            linked: lowering.table,
            start: try row(of: start),
            rows: rows,
            reached: Set(procedures.keys),
            types: types,
            variables: variables.reduce(into: [:]) { table, entry in
                table[entry.key] = (orderedVariables[entry.key] ?? []).map { name in
                    (name: name, value: entry.value[name] ?? .null)
                }
            }
        )
    }

    // MARK: - Private
}
