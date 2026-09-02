//
//  Linker.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this run was given and one name to start from, and answers
// with an image — or refuses.
//
// A link is handed its whole world at once. The words a program can send are
// the words the caller put in front of it, so what to link is the caller's
// statement and joining the names up is this. A module's `imports` says what it
// asks for and never where to find it, and the entry is an argument rather than
// a name written into a document.
//
// Unreached code is checked too. A misspelled procedure in a branch today's
// arguments never take is a defect whether or not this run walks that way, so
// linking follows the whole call graph and refuses on the first name it cannot
// resolve rather than on the first one a run happens to reach.
//
// Every send goes through the same gate: a library word and a procedure are
// checked against a signature by the same code, and the only difference is where
// the signature came from — the installed table, or another module in the same
// link.
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
    // What to link is the caller's statement — the whole world at once — and
    // `entry` names which declaration this run starts from. There is no default:
    // guessing which procedure was meant would be an opinion nobody gave.
    //
    // A bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func link(_ modules: [Module], entry: String) throws -> Image {
        // Type and constraint declarations first, because everything after
        // this reads type expressions against them. The qualifying pass owns
        // their uniqueness, so it hands over the tables that fact was proved on.
        try once(modules)

        let (declaredTypes, declaredConstraints) = try qualified(modules)

        let types = try types(
            of: modules,
            declared: declaredTypes,
            constraints: declaredConstraints
        )
        let symbols = try symbols(of: modules)

        // Every declaration under its qualified spelling. The spellings are
        // unique, since the symbol gathering refused a double, and every send
        // in every body asks this table.
        let space = symbols.reduce(into: [String: Symbol]()) { table, symbol in
            table[symbol.qualified] = symbol
        }

        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it, the module's name in front where
        // the module has one.
        guard let start = space[entry] else {
            throw LinkError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling, the module's name in front where"
                    + " it has one — declared: \(symbols.map(\.qualified).sorted().joined(separator: ", "))",
                at: nil
            )
        }

        // What every declaration returns, by the name a resolved call site
        // uses. Built before the walk so a call can be judged against a callee
        // the walk has not reached yet.
        let signatures = symbols.reduce(into: [String: Signature]()) { table, symbol in
            table[symbol.qualified] = symbol.procedure.signature
        }

        // Purity is worked out over every declaration rather than the reached
        // ones: a path names a word the call graph never mentions.
        let settled = pure(among: symbols)
        let (selectorSymbols, wordSymbols) = try derivable(among: symbols, pure: settled, in: types)

        // The tables as the author spelled them, and the form the link's own
        // settling reads: a written body is swapped for the refusal it would
        // earn, because it is itself still being resolved beside the
        // constants it may read — the table carries the fact, so no resolver
        // needs a flag saying when it runs.
        let written = selectorSymbols.mapValues(\.procedure)
        let wordsWritten = wordSymbols.mapValues(\.procedure)
        let settling = settleable(written)
        let settlingWords = settleable(wordsWritten)

        // Selectors and path words are two tables, because they are two
        // questions: what a selector reaches, and what a bare spelling a
        // walk writes may send. One table masked by a set let one spelling
        // answer with the other question's declaration.
        //
        // Both are filled with the answers read off bodies whose declaration
        // wrote none, and both by the same reading — a spelling that answers
        // one way through a call and another through a path would be one
        // declaration saying two things.
        var answeringSignatures = signatures
        var answeringWords = wordSymbols.mapValues { symbol in symbol.procedure.signature }

        // Which spellings a path reaches one declaration by — a word may be
        // reachable under more than one, and an answer worked out for it is
        // that declaration's however a walk spelled it.
        let wordSpellings = wordSymbols.reduce(into: [String: [String]]()) { spellings, entry in
            spellings[entry.value.qualified, default: []].append(entry.key)
        }

        func frame() -> TypeFrame {
            TypeFrame(
                symbols: space,
                signatures: answeringSignatures,
                types: types,
                words: answeringWords,
                pure: settled
            )
        }

        let declaredFrame = frame()

        // Settled after the words are known, because a constant may send one:
        // interpolation is `joined` now, and a constant that spells a URL out of
        // other constants is spelling it with words like any other expression.
        let constants = try constants(
            of: modules,
            reaching: settling,
            words: settlingWords,
            in: types,
            with: declaredFrame
        )

        // The names in scope before a body's first statement: its parameters,
        // and the constants its module declared beside them.
        func opening(_ symbol: Symbol, of signature: Signature) -> [String: TypeExpression] {
            environment(of: signature).merging(
                (constants[symbol.origin] ?? [:]).mapValues { value in type(of: value) }
            ) { _, constant in constant }
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

        // One declaration resolves once, whichever table asks — the frontier
        // for a reached body, the derivable tables for a body a path may run.
        var resolvedBodies: [String: (procedure: Procedure, calls: [CallSite])] = [:]

        // What a body's folding executes. Two moments hold two facts: while
        // the words themselves settle, a written body cannot run — a word
        // folding through a word would be a circle — so the stand-ins answer;
        // once the words are resolved, folding runs the same judged bodies a
        // run would, and the tables are swapped to say so.
        var foldingSelectors = settling
        var foldingWords = settlingWords

        // A declaration, bound and dot-judged: selectors resolve to qualified
        // spellings, every dot in the body is spelled as what the types say
        // it means, and a constant-headed path — judged first, like any path
        // — folds to the value it is. The image holds only this form, so a
        // run never asks a value what a name does.
        //
        // Every send the body writes is checked here too: whatever table put
        // this body in the image, the body runs, so the frontier's promise —
        // callee declared, arguments taken — is kept per body rather than per
        // reachability.
        func resolved(_ symbol: Symbol) throws -> (procedure: Procedure, calls: [CallSite]) {
            if let done = resolvedBodies[symbol.qualified] { return done }

            let declared = symbol.procedure

            var answer = (procedure: declared, calls: [CallSite]())

            if let block = declared.block {
                let folding = Resolver(
                    scope: Scope(bindings: constants[symbol.origin] ?? [:]),
                    selectors: foldingSelectors,
                    words: foldingWords,
                    types: types
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
                    folding: folding
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

            resolvedBodies[symbol.qualified] = answer

            try checked(answer.calls, in: frame)

            return answer
        }

        // The words first, and only the words: they are what every other
        // body's folding executes, so they settle before anything folds
        // through them. Their own constant paths meet the stand-ins — a word
        // folding through a word is the circle the stand-ins refuse — and
        // that is a fact of each word's own text, the same every link.
        // Nothing else resolves here: checking a word's calls does not
        // resolve the callees, so no other declaration is ever folded
        // against the stand-ins, and whether a declaration links stays a
        // fact of its text rather than of who happens to call it. In name
        // order, so which mistake is reported first is the text's fact too.
        var pathWords: [String: Procedure] = [:]

        for (name, symbol) in wordSymbols.sorted(by: { $0.key < $1.key }) {
            pathWords[name] = try resolved(symbol).procedure
        }

        // From here a fold runs judged bodies. Only the words are resolved
        // so far — a fold that walks from a word's body into another written
        // declaration still meets a stand-in, the same circle guard by the
        // same rule.
        foldingWords = pathWords
        foldingSelectors = settling.merging(
            resolvedBodies.mapValues(\.procedure)
        ) { _, resolved in resolved }

        var procedures: [String: Procedure] = [:]
        var frontier: [Symbol] = [start]
        var index = 0
        var linked: Procedure?

        // Breadth over the frontier, so the first refusal an author sees is the
        // first mistake they wrote. Memoising by qualified name is what makes a
        // recursive procedure link once instead of forever.
        while index < frontier.count {
            let symbol = frontier[index]
            index += 1

            if procedures[symbol.qualified] != nil { continue }

            let (resolved, calls) = try resolved(symbol)

            procedures[symbol.qualified] = resolved

            if symbol.qualified == start.qualified { linked = resolved }

            // A constant answer is knowable from the text, so it is held to the
            // declaration here, the way a constant argument is. An answer only
            // a run can produce is settled at the boundary instead.
            if let returns = resolved.signature.returns,
               let answer = resolved.block?.result?.constantValue {
                do {
                    _ = try returns.settling(answer, at: "answer", in: types)
                } catch {
                    throw LinkError(
                        "answers \(answer.type), and its"
                            + " declaration promises \(returns) — \(error)",
                        at: symbol.place.slot(.result)
                    )
                }
            }

            for call in calls {
                frontier.append(call.callee)
            }
        }

        // Every pure body compiles and has its sends checked, reached or not
        // — the same promise the frontier makes for the call graph. After the
        // frontier on purpose, so a mistake on a path from the entry is
        // reported before one in a declaration nothing reaches; in name
        // order, so which unreached mistake comes first is a fact of the
        // text rather than of a hash seed.
        var selectors: [String: Procedure] = [:]

        for (name, symbol) in selectorSymbols.sorted(by: { $0.key < $1.key }) {
            selectors[name] = try resolved(symbol).procedure
        }

        return Image(
            entry: linked ?? start.procedure,
            procedures: procedures,
            types: types,
            pure: settled,
            selectors: selectors,
            words: pathWords
        )
    }

    // MARK: - Private
    // No document twice. An identity is derived from the text, so two copies of
    // one are one document, and every name in it collides with itself.
    //
    // Refused here rather than left to the collision, because the collision has
    // nothing to say: both sides of its sentence are the same document, and the
    // fix is not a spelling but a caller holding what it already had.
    private func once(_ modules: [Module]) throws {
        var held: Set<Identity> = []

        for module in modules {
            guard let identity = module.identity else { continue }
            guard held.insert(identity).inserted else {
                throw LinkError(
                    "this document was handed to the link twice — a link states"
                        + " its whole world once, so a document already in it is"
                        + " not something to add",
                    at: Place(in: .of(module))
                )
            }
        }
    }

    // The one gate every gathered send passes, wherever its body sits — a
    // procedure, a word, a constant's closure. The call carries the
    // declaration the walk found for it, and is judged against that.
    private func checked(_ calls: [CallSite], in frame: TypeFrame) throws {
        for call in calls {
            try check(call, against: call.callee.procedure, with: frame)
        }
    }

    // The tables the link's own settling reads. A native word answers at the
    // link; a written body is itself still being resolved beside the
    // constants it may read, so it is swapped for the refusal it would earn —
    // present, judged and named, and never run half-made.
    private func settleable(_ table: [String: Procedure]) -> [String: Procedure] {
        table.mapValues { procedure in
            guard procedure.block != nil else { return procedure }

            return Procedure(
                description: procedure.description,
                signature: procedure.signature,
                implementation: .query(UnsettledWord())
            )
        }
    }

    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls.
    //
    // Optimistic and iterated: everything with a body starts as a candidate and
    // is struck out when something it reaches is not pure. Starting from "impure
    // until proven" would make two procedures that call each other permanently
    // impure, which is a fact about the algorithm rather than about the code.
    private func pure(among symbols: [Symbol]) -> Set<String> {
        let bodies = symbols.reduce(into: [String: Block?]()) { table, symbol in
            table[symbol.qualified] = symbol.procedure.block
        }

        var pure = Set(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyPure != false }
                .map(\.qualified)
        )

        while true {
            let struck = pure.filter { name in
                guard let block = bodies[name], let block else { return false }

                return !isPure(block, given: pure)
            }

            guard !struck.isEmpty else { return pure }

            pure.subtract(struck)
        }
    }

    // A block answers without running when every part of it is something the
    // pure evaluator can answer, and every name it sends to is pure. Control
    // flow is not in that set — not because running a branch is impure, but
    // because the surface that answers purely does not run bodies at all. A
    // selector is the declared spelling it names, so the table is asked by the
    // selector as written.
    func isPure(_ block: Block, given pure: Set<String>) -> Bool {
        block.body.allSatisfy { statement in
            statement.binding == .constant && isPure(statement.expression, given: pure)
        }
            && (block.result.map { result in isPure(result, given: pure) } ?? true)
    }

    private func isPure(_ expression: Expression, given pure: Set<String>) -> Bool {
        func isPure(_ inner: Expression) -> Bool {
            self.isPure(inner, given: pure)
        }

        switch expression {
        case .literal, .reference, .closure:
            return true

        // Leaving is not a computation, and what it does is not something the
        // pure evaluator can do: purity here means "can be answered without
        // running", and this one answers by not answering. Asking only what it
        // carries would let it through to a slot the resolver then refuses.
        case .leave:
            return false

        // Judging a value against a shape reaches nothing outside itself, so a
        // cast is as pure as what it reads.
        case let .cast(value, _, _):
            return isPure(value)

        case let .array(array):
            return array.allSatisfy(isPure)

        case let .record(record):
            return record.values.allSatisfy(isPure)

        case let .dispatch(dispatch):
            return pure.contains(dispatch.selector)
                && (dispatch.receiver.map(isPure) ?? true)
                && dispatch.arguments.values.allSatisfy(isPure)

        // Calling a value is settled at run time, so nothing here can say what
        // it reaches. A body that does it is not answerable purely.
        case .invoke:
            return false

        case .block, .conditional, .loop, .iteration, .attempt:
            return false
        }
    }

    // What can be answered without running, under every name something may look
    // it up by. Two names, because there are two ways to reach one:
    //
    //   `std.count`  — a selector, resolved at link like any other
    //   `count`      — a path segment. `x.count` names no module, because the
    //                  front end cannot know whether a trailing segment is a
    //                  field or a word, so this is the one name still answered
    //                  at run time — and the one place an ambiguity has to be
    //                  refused before the run rather than during it.
    //
    // Built from every declaration rather than the reached ones: a path names a
    // word the call graph never mentions, so reachability is the wrong question.
    private func derivable(
        among symbols: [Symbol],
        pure: Set<String>,
        in types: TypeTable
    ) throws -> (selectors: [String: Symbol], words: [String: Symbol]) {
        var selectors: [String: Symbol] = [:]
        var words: [String: Symbol] = [:]
        // Every declaration that contests a name, and not only that one is
        // contested. Nothing a path writes can tell them apart, so the fix is
        // on a declaration — which makes all of them something a reader has to
        // be able to reach. A slot holding the latest collision would keep the
        // newest two and drop whoever took the name first, so a third arrival
        // hides the declaration the other two are colliding with.
        var contested: [String: [Symbol]] = [:]

        // Two tables, because a name answers two different questions — what a
        // selector reaches, and what a bare spelling a path writes may send.
        // One table held both and let a declaration whose qualified name
        // matched another's bare spelling quietly answer the wrong question.
        // Symbols rather than procedures, because the bodies are still to be
        // read: the caller reads them through the same judgment every reached
        // body takes.
        for symbol in symbols.sorted(by: { $0.qualified < $1.qualified }) {
            guard pure.contains(symbol.qualified) else { continue }

            selectors[symbol.qualified] = symbol

            guard symbol.procedure.signature.isDerivable(in: types) else { continue }

            let bare = symbol.qualified.split(separator: ".").last.map(String.init)
                ?? symbol.qualified

            // Only two words a path could both reach are ambiguous. A
            // declaration a path cannot reach shares the link but not the
            // question, so it is not competing for the name.
            if let first = words.updateValue(symbol, forKey: bare) {
                contested[bare, default: [first]].append(symbol)
            }
        }

        // The place is one declaration and the sentence names every contested
        // word, so the name that is walked to is picked in sorted order — the
        // order a dictionary hands its keys back is seeded per process, and
        // which declaration an author is sent to would change between runs.
        //
        // The second is what is walked to, the way it is wherever two
        // declarations collide. A name reaches this table only by colliding,
        // so there are always at least two.
        if let (word, declarations) = contested.min(by: { one, other in one.key < other.key }) {
            // In the order the caller handed the modules over, which is the
            // order every collision refusal is read in: the second is the one
            // that could not be added. Gathered in name order above, because
            // that is the order the tables are built in, so the two are sorted
            // apart here rather than one being made to serve for both.
            let ranked = declarations.sorted { one, other in one.origin < other.origin }

            throw LinkError(
                "\(contested.keys.sorted().joined(separator: ", ")) is declared by more"
                    + " than one module as something a path may reach — '\(word)' by"
                    + " \(ranked.map(\.qualified).joined(separator: ", "))"
                    + " — a path segment names no module, so there is no spelling that"
                    + " would tell them apart",
                at: ranked[1].place
            )
        }

        return (selectors, words)
    }

    // Every declaration, qualified. A module with a name declares into that
    // name; a module without one declares into the shared space, and two of
    // those cannot both declare a name for the same reason two `.c` files
    // cannot both define a symbol.
    private func symbols(of modules: [Module]) throws -> [Symbol] {
        var symbols: [Symbol] = []

        // The declaration that took each name, rather than only that the name
        // is taken. A refusal about a name declared twice is addressed to the
        // declaration that cannot be added and names both in the sentence — a
        // set answers neither half, and the place alone answers neither when
        // the two documents were never written down.
        var claimed: [String: Symbol] = [:]

        for (origin, module) in modules.enumerated() {
            for name in module.procedures.keys.sorted() {
                guard let procedure = module.procedures[name] else { continue }

                let qualified = module.qualified(name)

                let symbol = Symbol(
                    declared: name,
                    document: .of(module),
                    origin: origin,
                    procedure: procedure
                )

                if let first = claimed[qualified] {
                    throw LinkError(
                        "'\(qualified)' is declared more than once in this link — by"
                            + " \(first.spelled) and \(symbol.spelled) — two declarations"
                            + " of a name have no way to be told apart",
                        at: symbol.place
                    )
                }

                claimed[qualified] = symbol

                symbols.append(symbol)
            }
        }

        return symbols
    }

    // Every shape the modules declared, and the check that each name a
    // declaration mentions is one of them. A type name is resolved here for the
    // same reason a procedure name is: unreached code still has to compile, and
    // a signature naming a shape nobody declared is a defect whether or not this
    // run walks that way.
    // The spaces arrive gathered from the qualifying pass — the one place
    // their uniqueness is refused, so what this judges is what that fact was
    // proved on. This judges content: what a declaration holds, not what it
    // is called.
    private func types(
        of modules: [Module],
        declared: [String: Declared<TypeExpression>],
        constraints members: [String: Declared<[TypeExpression]>]
    ) throws -> TypeTable {
        // A name that reaches a shape may name itself along the way — `Tree`
        // holding `array<Tree>` is a shape. A name that reaches only names
        // never becomes one, and everything that resolves names would chase
        // it forever — so the cycle is refused here, and every later walk
        // through `named` is finite because of it.
        for (name, declaration) in declared.sorted(by: { $0.key < $1.key }) {
            var seen: Set<String> = [name]
            var current: TypeExpression? = declaration.held

            while case let .named(next) = current {
                guard seen.insert(next).inserted else {
                    throw LinkError(
                        "reaches itself through nothing but names"
                            + " — a name that only names names never reaches a shape",
                        at: declaration.place
                    )
                }

                current = declared[next]?.held
            }
        }

        for (name, declaration) in members.sorted(by: { $0.key < $1.key }) {
            let admitted = declaration.held

            guard !admitted.isEmpty else {
                throw LinkError(
                    "admits nothing, so no parameter it"
                        + " bounds could ever be filled",
                    at: declaration.place
                )
            }

            // A member is a concrete shape. `some` stands for a type and
            // names none, `any` would admit everything a membership exists
            // to narrow, and `never` admits nothing — each is a
            // declaration that says nothing a membership could hold, and
            // a member that names another constraint is what keeps the
            // membership judgment from ever chasing itself. Judged through
            // every name a member hides behind, or one alias would carry
            // the refused shape in — the chain is finite because a
            // name-only cycle was refused above.
            for member in admitted {
                var resolved = member

                while case let .named(next) = resolved, let underneath = declared[next] {
                    resolved = underneath.held
                }

                switch resolved {
                case .variable, .any, .never:
                    throw LinkError(
                        "a member is a concrete shape"
                            + " — `\(member.rendered)` says nothing a"
                            + " membership could hold",
                        at: declaration.place
                    )

                default:
                    break
                }
            }
        }

        let table = TypeTable(
            types: declared.mapValues(\.held),
            constraints: members.mapValues(\.held)
        )

        // The two spaces are walked from the tables rather than per module:
        // they arrive carrying where each name was written, and asking a module
        // again would be spelling that a second way.
        for (_, declaration) in declared.sorted(by: { $0.key < $1.key }) {
            try mentioned(
                in: declaration.held,
                at: declaration.place,
                parameterized: false,
                resolve: table
            )
        }

        for (_, declaration) in members.sorted(by: { $0.key < $1.key }) {
            for member in declaration.held {
                try mentioned(
                    in: member,
                    at: declaration.place,
                    parameterized: false,
                    resolve: table
                )
            }
        }

        for module in modules {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                try judge(procedure.signature, at: .procedure(name, in: .of(module)), in: table)

                // A closure literal carries a signature the way a declaration
                // does, and unreached code still has to compile — so what the
                // top level is held to, a signature written inline is held to
                // in the same pass, wherever a body buries it.
                if case let .body(block) = procedure.implementation {
                    let buried = block.buried(at: .procedure(name, in: .of(module)))

                    for (place, inner) in closures(in: buried) {
                        try judge(inner.signature, at: place, in: table)
                    }

                    // A cast names a shape, which is a mention like a
                    // signature's — so it is held here, in the same pass and
                    // by the same rule. Asking it where types are inferred
                    // instead would ask only of what that walk reaches:
                    // a procedure both impure and unreachable is walked by
                    // neither the frontier nor the pure set, and its casts
                    // would name whatever they liked.
                    for (place, named) in castTypes(in: buried) {
                        try judge(cast: named, at: place, in: table)
                    }
                }
            }

            for (name, constant) in module.constants.sorted(by: { $0.key < $1.key }) {
                let buried = constant.buried(at: .constant(name, in: .of(module)))

                for (place, inner) in closures(in: buried) {
                    try judge(inner.signature, at: place, in: table)
                }

                for (place, named) in castTypes(in: buried) {
                    try judge(cast: named, at: place, in: table)
                }
            }
        }

        return table
    }

    // Everything a signature is held to where it is declared: every type it
    // mentions resolves, every parameter could be filled, every constraint it
    // names is declared and single, and the receiver it names is a parameter
    // it declares — the facts every consumer of the signature reads instead
    // of re-deriving.
    private func judge(
        _ signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        for (input, parameter) in signature.parameters.sorted(by: { $0.key < $1.key }) {
            try mentioned(
                in: parameter.declared,
                at: place.slot(.parameters).key(input),
                parameterized: true,
                resolve: table
            )
            try judge(parameter, called: input, at: place.slot(.parameters).key(input), in: table)
        }

        try mentioned(
            in: signature.returns ?? .any,
            at: place.slot(.returns),
            parameterized: true,
            resolve: table
        )

        try judgeConstraints(of: signature, at: place, in: table)

        if let receiver = signature.receiver, signature.parameters[receiver] == nil {
            throw LinkError(
                "receiver names '\(receiver)', which this"
                    + " signature does not declare",
                at: place
            )
        }
    }

    // Everything a cast's shape is held to on its spelling alone: the names
    // it mentions resolve, and it names a shape there is something to read.
    // Both are answered without knowing what the value reads as, so both
    // belong to the pass that sees every cast rather than to the walk that
    // sees the reached ones — a procedure both impure and unreachable is
    // walked by neither the frontier nor the pure set.
    private func judge(
        cast named: TypeExpression,
        at place: Place,
        in table: TypeTable
    ) throws {
        try mentioned(in: named, at: place, parameterized: true, resolve: table)

        if let refusal = named.resolved(in: table).unreadableClaim {
            throw LinkError(refusal, at: place)
        }
    }

    // Every shape a cast names in here, however deep, each with where it was
    // found. What the walk buries is `buried`'s to know — this says only which
    // of it a cast scan keeps.
    private func castTypes(
        in buried: [(Place, Expression)]
    ) -> [(Place, TypeExpression)] {
        buried.compactMap { place, expression in
            guard case let .cast(_, named, _) = expression else { return nil }

            return (place, named)
        }
    }

    // Every closure literal in here, however deep, each with where it was
    // found. A closure's own body may hold more of them, and the one walk goes
    // through the one it found.
    private func closures(
        in buried: [(Place, Expression)]
    ) -> [(Place, Procedure)] {
        buried.compactMap { place, expression in
            guard case let .closure(procedure) = expression else { return nil }

            return (place, procedure)
        }
    }

    // Whether a signature's bounded parameters could ever be judged: every
    // constraint it names has to be one somebody declared, and one parameter
    // takes one constraint — each occurrence carries its bound separately, so
    // occurrences carrying different bounds for one name are two claims about
    // one thing.
    private func judgeConstraints(
        of signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        var bounds: [String: Set<String>] = [:]
        signature.parameterConstraints(into: &bounds)

        for (parameter, names) in bounds.sorted(by: { $0.key < $1.key }) {
            guard names.count <= 1 else {
                throw LinkError(
                    "`some \(parameter)` is bounded by"
                        + " \(names.sorted().joined(separator: " and "))"
                        + " — one parameter takes one constraint",
                    at: place
                )
            }

            guard let bound = names.first, table.constraint(bound) == nil else { continue }

            throw LinkError(
                "`some \(parameter)` names constraint '\(bound)',"
                    + " which no module in this link declares",
                at: place
            )
        }
    }

    // A named type may name itself, so this checks that a name resolves rather
    // than walking into what it resolves to.
    //
    // `parameterized` says whether a type parameter written here has a call to
    // fill it. A signature's slots do — the walk into a procedure type turns
    // it on — and a declared type or a constraint member does not: a
    // parameter there would stand for nothing any call ever decides, so it is
    // refused where it is declared, and everything a `named` type can hide is
    // judged here rather than at the sites that name it.
    // Internal, because a cast asks it too: a type spelling in a body is a
    // mention like any other, and a second copy of "this name is declared"
    // living in the typing walk is exactly the drift the rule exists against.
    func mentioned(
        in type: TypeExpression,
        at place: Place,
        parameterized: Bool,
        resolve table: TypeTable
    ) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes:
            return

        // The link's own note to itself, written where a declaration goes. A
        // declaration is a promise, and this is a shape worked out from a body
        // — nobody promised it, and no document could have spelled it. It is
        // refused here rather than left to the reader, because a reader is one
        // way a declaration is built and a host assembling one is another.
        case let .reading(of, path):
            throw LinkError(
                "writes `\(type.rendered)`, which is a shape the link"
                    + " read out of a body — a declaration says what a call fills,"
                    + " and `\(([PathSegment.key(of)] + path).rendered)` is a path"
                    + " only that body can read",
                at: place
            )

        // The bounds are the declaration's own claim, so an order the numbers
        // refuse is refused where it was written — a range below its own floor
        // is a slot no call could ever fit, the way an empty `oneOf` is.
        case let .ranged(refinement):
            if refinement.saysNothing {
                throw LinkError(
                    "writes `\(type.rendered)` with neither bound"
                        + " — a range that says nothing is spelled"
                        + " `\(refinement.kind.rendered)`",
                    at: place
                )
            }

            if refinement.admitsNothing {
                throw LinkError(
                    "writes `\(type.rendered)`, which admits nothing"
                        + " — no \(refinement.kind.rendered) is inside it",
                    at: place
                )
            }

            return

        case .variable:
            guard parameterized else {
                throw LinkError(
                    "writes `\(type.rendered)`, and nothing here is"
                        + " filled by a call — a type parameter lives in a signature",
                    at: place
                )
            }

        // The flag rides through rather than turning on: a procedure type in a
        // signature's slot is part of that signature, and one in a declared
        // type is not a filling site — a parameter written there is never
        // bound at any call, so the bound it claims would be a claim nothing
        // judges.
        case let .procedure(signature, _):
            guard let signature else { return }

            for (name, parameter) in signature.parameters.sorted(by: { $0.key < $1.key }) {
                try mentioned(
                    in: parameter.declared,
                    at: place.key(name),
                    parameterized: parameterized,
                    resolve: table
                )
                try judge(parameter, called: name, at: place.key(name), in: table)
            }

            try mentioned(
                in: signature.returns ?? .any,
                at: place,
                parameterized: parameterized,
                resolve: table
            )

            try judgeConstraints(of: signature, at: place, in: table)

        case let .named(name):
            guard table.resolve(name) != nil else {
                throw LinkError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

        case let .array(element), let .object(element):
            try mentioned(in: element, at: place, parameterized: parameterized, resolve: table)

        // The reader refuses a `?` that says nothing new — but the reader
        // sees spellings, and a name may hide one of the refused shapes
        // behind it. The rule is the model's, so it is held here too, where
        // names resolve: whatever surface wrote the type, `?` wraps only what
        // does not already answer the null question.
        case let .nullable(inner):
            var resolved = inner

            while case let .named(next) = resolved, let underneath = table.resolve(next) {
                resolved = underneath
            }

            switch resolved {
            case .any, .null, .never, .variable, .nullable:
                throw LinkError(
                    "writes `?` on \(inner.rendered), which"
                        + " stands for `\(resolved.rendered)` — a `?` says"
                        + " nothing there, the same rule the spelling"
                        + " `\(resolved.rendered)?` is refused by",
                    at: place
                )

            default:
                break
            }

            try mentioned(in: inner, at: place, parameterized: parameterized, resolve: table)

        case let .record(fields):
            for (name, field) in fields.sorted(by: { $0.key < $1.key }) {
                try mentioned(
                    in: field,
                    at: place.key(name),
                    parameterized: parameterized,
                    resolve: table
                )
            }
        }
    }

    // Whether a parameter's own declaration can be satisfied at all — facts it
    // states about itself, judged wherever a parameter is written: a `oneOf`
    // none of whose candidates the declared type admits is a parameter no call
    // could ever fit, and a default the parameter itself would refuse is a
    // refusal waiting for the one call that leans on it.
    private func judge(
        _ parameter: Parameter,
        called name: String,
        at place: Place,
        in table: TypeTable
    ) throws {
        if let allowed = parameter.oneOf {
            // Candidate by candidate: a spelling the declared type cannot
            // spell is a member no call could ever match, and a dead member
            // is the declaration's own defect whether live ones stand beside
            // it or not. One pass reads both facts — a list that is empty or
            // entirely dead refuses by the plainer name, a dead member among
            // live ones is named.
            let dead = allowed.filter { candidate in
                !spellable(candidate, as: parameter.declared, resolve: table)
            }

            if dead.count == allowed.count {
                throw LinkError(
                    "oneOf admits nothing, so no call could ever fit",
                    at: place
                )
            }

            if let first = dead.first {
                throw LinkError(
                    "oneOf lists '\(first)', which"
                        + " \(parameter.declared.rendered) does not admit —"
                        + " no call could ever match it",
                    at: place
                )
            }
        }

        guard let fallback = parameter.default else { return }

        // An explicitly-null default is the value the body receives when the
        // argument is left out, so the declaration must admit null like any
        // other value — and a `oneOf` never lists it, since null has no scalar
        // spelling.
        if fallback == .null {
            guard parameter.oneOf == nil, admitsNull(parameter.declared, resolve: table) else {
                throw LinkError(
                    "its default is not a value it takes — null",
                    at: place
                )
            }

            return
        }

        do {
            _ = try parameter.checking(fallback, called: name, in: table)
        } catch {
            throw LinkError(
                "its default is not a value it takes — \(error)",
                at: place
            )
        }
    }

    // Whether a `oneOf` candidate could ever be a spelling of a value of this
    // type — a different question from a constraint's membership, so a
    // different name. Candidates are written as the scalar spellings arguments
    // are compared under, so a type with no scalar spelling can spell none of
    // them.
    private func spellable(
        _ candidate: String,
        as type: TypeExpression,
        resolve table: TypeTable
    ) -> Bool {
        switch type {
        // Filled by the call, so nothing about the candidates is knowable
        // here — the same answer an unbounded parameter gives, for the same
        // reason.
        case .any, .string, .reading:
            return true

        case .int:
            return Int(spelling: candidate) != nil

        // A candidate has to be a value the range itself would admit — a
        // `oneOf` past the bounds is a candidate no call could ever fit. Read
        // as the kind under the range and judged by the range's own judge, so
        // what the link calls dead is exactly what the boundary would refuse.
        case let .ranged(refinement):
            guard let value = Parameter.numeral(candidate, as: refinement.kind, in: table) else {
                return false
            }

            guard case .settled = refinement.settling(value) else { return false }

            return true

        // A candidate is alive exactly when some arriving value spells as it,
        // so the judge asks the value's one spelling rather than a looser
        // parse — `1e0` and `1.00` read as fractions, but no fraction spells
        // that way, so no call could ever match them.
        // The boundary's own candidate reading, so what the link calls a
        // dead member is exactly what the boundary would never match.
        case .double, .number:
            return Parameter.numeral(candidate, as: type, in: table) != nil

        case .bool:
            return candidate == "true" || candidate == "false"

        // An unbounded type parameter is filled by the call, so nothing about
        // the candidates is knowable here. A bounded one takes only what some
        // member of its constraint could spell — a `oneOf` of words on a
        // Numeric slot fits no call, and that is knowable where the parameter
        // is declared.
        case let .variable(_, constraint):
            guard let constraint, let members = table.constraint(constraint) else {
                return true
            }

            return members.contains { member in
                spellable(candidate, as: member, resolve: table)
            }

        case let .named(name):
            guard let resolved = table.resolve(name) else { return false }

            return spellable(candidate, as: resolved, resolve: table)

        // A candidate spells a value, and null is not one a `oneOf` lists — so
        // a nullable slot's candidates are the declared half's.
        case let .nullable(inner):
            return spellable(candidate, as: inner, resolve: table)

        case .null, .never, .bytes, .array, .object, .record, .procedure:
            return false
        }
    }

    private func admitsNull(
        _ type: TypeExpression,
        resolve table: TypeTable
    ) -> Bool {
        switch type {
        case .any, .null, .nullable:
            return true

        case let .named(name):
            guard let resolved = table.resolve(name) else { return false }

            return admitsNull(resolved, resolve: table)

        default:
            return false
        }
    }

    // Each module's constants, settled. They are evaluated here because there is
    // nothing about them left for a run to do: a constant sees no scope, so what
    // it will be is knowable the moment the document is read.
    //
    // One may name another declared beside it, so they are settled in the order
    // they read each other and that order is worked out first. What is wrong
    // with a set of constants is a fact about that order, and asking the order
    // is the whole of finding it.
    private func constants(
        of modules: [Module],
        reaching selectors: [String: Procedure],
        words: [String: Procedure],
        in types: TypeTable,
        with frame: TypeFrame
    ) throws -> [Int: [String: Value]] {
        var settled: [Int: [String: Value]] = [:]

        for (origin, module) in modules.enumerated() where !module.constants.isEmpty {
            var known: [String: Value] = [:]

            // Handed over with what each one reads, so nothing looks a name
            // back up in the table the order was read from — everything this
            // one needs comes before it, and asking again is a second chance
            // to ask a different table.
            for (name, expression) in try order(of: module) {
                let resolver = Resolver(
                    scope: Scope(bindings: known),
                    selectors: selectors,
                    words: words,
                    types: types
                )

                // A constant's dots are judged before it settles, the way a
                // body's are: the settled neighbours' types are the
                // environment, so an absent field or a needless `?.` refuses
                // here by the one rule, and carries its own place.
                let (judged, calls) = try resolvedSites(
                    in: expression,
                    at: .constant(name, in: .of(module)),
                    in: known.mapValues { value in type(of: value) },
                    with: frame,
                    folding: nil
                )

                // A closure a constant holds runs later, so evaluating
                // the constant proves nothing about the sends inside it —
                // they pass the same gate every gathered send does.
                try checked(calls, in: frame)

                do {
                    known[name] = try resolver.resolve(judged)
                } catch {
                    throw LinkError("\(error)", at: .constant(name, in: .of(module)))
                }
            }

            settled[origin] = known
        }

        return settled
    }

    // The order a module's constants settle in: what a constant reads comes
    // before it. Constants that wait on each other have no such order, and that
    // is refused here, standing on one of them.
    private func order(of module: Module) throws -> [(name: String, expression: Expression)] {
        let constants = module.constants

        var ordered: [(name: String, expression: Expression)] = []
        var settled: Set<String> = []

        // What the walk is standing on, root first. Where it meets a name
        // already on it, everything from that name down is the circle — and
        // nothing above it is, which is the difference between what names
        // itself back and what merely waits on something that does.
        var walking: [String] = []

        func place(_ name: String, reading expression: Expression) throws {
            guard !settled.contains(name) else { return }

            if let met = walking.firstIndex(of: name) {
                let circle = walking[met...].sorted()

                throw LinkError(
                    "constants \(circle.joined(separator: ", ")) name each other in a"
                        + " circle — a constant may name another declared beside it, but"
                        + " not one that names it back",
                    // Any of them is where the fix can be made, so the one
                    // walked to is the first in sorted order: a circle has no
                    // first member, and reading one off the walk would name a
                    // different constant depending on where the walk started.
                    at: .constant(circle[0], in: .of(module))
                )
            }

            walking.append(name)

            // Sorted, so a module with two mistakes in it refuses the same one
            // every run — what a set hands back is seeded per process.
            for read in mentions(of: expression).intersection(constants.keys).sorted() {
                // Intersected with these keys, so the walk cannot be sent to a
                // name that is not one of them.
                try place(read, reading: constants[read]!)
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
    // the spelling. A closure's body is walked with
    // the rest — making one captures the scope it was written in, so a sibling
    // it reads has to be settled by then.
    private func mentions(of expression: Expression) -> Set<String> {
        expression.buried.reduce(into: Set<String>()) { names, held in
            guard case let .reference(path) = held else { return }

            names.formUnion(path.expandingIndexReferences.compactMap(\.head))
        }
    }

    private func check(
        _ site: CallSite,
        against callee: Procedure,
        with frame: TypeFrame
    ) throws {
        let dispatch = site.dispatch
        let types = frame.types

        // A declaration with a type parameter in it is checked with the
        // parameter filled, or a slot standing for whatever arrives would
        // refuse whatever arrived. The judgment — a parameter read two ways
        // has no answer, a bounded one takes only what its constraint admits —
        // is the one every send surface shares, so this only gathers what the
        // call wrote into each slot. This is what one signature says in place
        // of the several a language with overloading would need: `some N` on
        // both sides and on the way out is a whole number and a whole number
        // answering a whole number, and a whole number and a fraction refused,
        // without a way to declare a name twice.
        let declared = callee.signature

        let signature: Signature

        switch judged(
            declared,
            filledWith: bound(
                of: declared,
                at: dispatch,
                readings: site.readings,
                receiver: site.received,
                in: types
            ),
            in: types
        ) {
        case let .refusal(reason):
            throw LinkError(
                "sending '\(dispatch.selector)' — \(reason)",
                at: site.place
            )

        case let .fits(filled):
            signature = filled
        }
        let undeclared = dispatch.arguments.keys
            .filter { name in signature.parameters[name] == nil }
            .sorted()

        guard undeclared.isEmpty else {
            throw LinkError(
                "sending '\(dispatch.selector)' with"
                    + " \(undeclared.joined(separator: ", ")), which it does not declare",
                at: site.place.slot(.arguments)
            )
        }

        // A receiver is written on the other side of the dot rather than by
        // name, so a site that sends one has supplied that parameter.
        let supplied = Set(dispatch.arguments.keys)
            .union(dispatch.receiver == nil ? [] : [signature.receiver].compactMap { $0 })

        let missing = signature.parameters
            .filter { name, parameter in
                parameter.mustBeGiven(in: types) && !supplied.contains(name)
            }
            .keys
            .sorted()

        guard missing.isEmpty else {
            throw LinkError(
                "sending '\(dispatch.selector)' without"
                    + " \(missing.joined(separator: ", ")), which it requires",
                at: site.place.slot(.arguments)
            )
        }

        // An argument that needs a scope cannot be judged here — only the ones
        // that already are what they will be. `taking` rather than `checking`,
        // so a constant passes exactly the gate the run would apply to it.
        for (name, argument) in dispatch.arguments.sorted(by: { left, right in left.key < right.key }) {
            guard
                let parameter = signature.parameters[name],
                let constant = argument.constantValue
            else {
                continue
            }

            do {
                _ = try parameter.taking(constant, called: name, in: types)
            } catch {
                throw LinkError(
                    "sending '\(dispatch.selector)' — \(error)",
                    at: site.place.argument(name)
                )
            }
        }

        // A word may judge its own constant arguments before any run — a type
        // cannot say that a regex pattern compiles, and the word can. It happens
        // here rather than while decoding, because a notation judging arguments
        // would have to know the vocabulary; judging belongs where names resolve.
        if case let .query(query) = callee.implementation {
            let constants = dispatch.arguments.compactMapValues(\.constantValue)

            do {
                try query.validate(constants)
            } catch {
                throw LinkError(
                    "sending '\(dispatch.selector)' — \(error)",
                    at: site.place.slot(.arguments)
                )
            }
        }

        // What an argument holds is read from the body it was written in, so a
        // name bound to a call carries that call's declared answer. This is what
        // makes declaring an answer worth anything before a run: both sides are
        // declarations, and a declaration is text. The site carries the walk's
        // readings, so nothing is walked again for the asking.
        for name in dispatch.arguments.keys.sorted() {
            guard let parameter = signature.parameters[name] else { continue }

            let written = site.readings[name] ?? .any

            guard !parameter.declared.accepts(written, in: types) else { continue }

            throw LinkError(
                "sending '\(dispatch.selector)' with \(name),"
                    + " which holds \(written) where \(parameter.declared) is declared",
                at: site.place.argument(name)
            )
        }

        // The receiver is written on the other side of the dot and checked the
        // same way.
        if
            let written = site.received,
            let name = signature.receiver,
            let parameter = signature.parameters[name]
        {
            guard parameter.declared.accepts(written, in: types) else {
                throw LinkError(
                    "sending '\(dispatch.selector)' to \(written),"
                        + " where \(parameter.declared) is declared",
                    at: site.place.slot(.receiver)
                )
            }
        }
    }

}
