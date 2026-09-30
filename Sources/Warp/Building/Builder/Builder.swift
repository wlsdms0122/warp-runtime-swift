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
// Two stages. Compiling settles everything a document says against the
// interfaces it reaches: its declarations (`DeclarationChecker`), what it
// claims (`ClaimChecker`), the facts nobody declared (`Derivation`), its
// bodies (`TypeChecker`, `LinearityChecker`) and lowering (`Lowering`). It
// runs the procedures a constant calls, which is what folding is. Linking
// takes what that answered, judges what only the whole list can answer, and
// runs nothing.
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

        try once(compiled.map(\.document))
        try against(compiled)

        // Laid end to end through the door a link lays documents through, so a
        // name two of them declare is refused here as it is there.
        let assembled = try Assembled(compiled)
        let linkage = Linkage()
        let namespace = try TypeNamespace(compiled)
        let declaring = try DeclarationChecker().types(of: namespace, numbered: linkage)

        let signatures = try signatures(of: assembled, in: declaring.loweredTypes)

        // Which types answer which contracts among these documents. A row
        // whose signature names a contract lowers against that reading, so it
        // is worked out here rather than left to the compile that asks.
        let lowered = try ClaimChecker().lowered(declaring, in: namespace, among: signatures)

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
                    closure: document.closure(ofRow: index),
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

        try compiling.resolveHeldClosures()
        try compiling.resolveEvery()

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

        try once(modules.map(Place.Document.of), held: laid.identities)

        try refuseDoubled(modules, after: compiled.count)

        let namespace = try TypeNamespace(compiled + modules)
        let standing = try ModuleGraph(modules, after: compiled.count).standing
        let lowered = try await compile(modules, at: standing, over: namespace, against: laid)

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
        over namespace: TypeNamespace,
        against laid: Laid
    ) async throws -> [Compiled] {
        let compiled = laid.compiled
        let laying = standing.map { position in modules[position] }
        let documents: [any Declaring] = compiled + laying

        let declaring = try DeclarationChecker().types(of: namespace, numbered: laid.linkage)

        try DeclarationChecker().judge(laying, in: declaring)

        // Every declaration these documents are compiled beside, by the
        // spelling it was declared by: what the documents behind them left on
        // their rows, and what they wrote themselves. A name two of them
        // declare is refused here.
        //
        // Refused rather than taken as the caller's statement, which the order
        // is: a doubled spelling is not a question of which document to read
        // first, it is a table with no answer for that name.
        var signatures = laid.signatures

        // The declarations of each document laid down, under the row it will
        // take here. What a document declares is its own; where the rows stand
        // is this compile's.
        let holding = standing.enumerated().map { offset, position in
            let module = modules[position]

            return module.procedures.sorted { $0.key < $1.key }.map { name, procedure in
                Symbol(
                    declared: name,
                    document: .of(module),
                    origin: compiled.count + offset,
                    handed: compiled.count + position,
                    procedure: procedure
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
            in: namespace,
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
            let object = try await Compiler().compile(
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
        try once(compiled.map(\.document))
        try against(compiled)

        // Every document's block laid down, which is where its rows first
        // stand somewhere. What a name reaches is answered from here on.
        let assembled = try Assembled(compiled)

        // The types of this link, made from what its documents declared and
        // laid down in the order their blocks are. Which types answer which
        // contracts is read across the documents, so the rows a body stands on
        // are answered here rather than carried out of a compile.
        let namespace = try TypeNamespace(compiled)
        let declaring = try DeclarationChecker().types(of: namespace, numbered: Linkage())
        let signatures = try signatures(of: assembled, in: declaring.loweredTypes)

        let lowered = try ClaimChecker().lowered(
            declaring,
            in: namespace,
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
    //
    // What the build read off a body is written in its document's type
    // numbers, so it is read as the rows of `loweredTypes`.
    private func signatures(
        of assembled: Assembled,
        in loweredTypes: LoweredTypeTable
    ) throws -> [Name: Placed<Declared>] {
        var signatures: [Name: Placed<Declared>] = [:]
        var numbered: [Int: LoweredTypeNumbering.Rows] = [:]

        for (name, number) in assembled.rows {
            let row = assembled.table[number]
            let place = Place.procedure(name.spelling, in: assembled.documents[row.origin])
            var answer: LoweredType?

            if let read = assembled.answers[number] {
                let rows = numbered[row.origin] ?? assembled.typeNumbering[row.origin].rows(in: loweredTypes)

                numbered[row.origin] = rows
                answer = try rows.read(read, at: place)
            }

            signatures[name] = Placed(
                Declared(
                    signature: row.judged.signature,
                    access: row.judged.access,
                    facts: (row.judged.constness, row.judged.isolation, answer)
                ),
                at: place,
                of: row.origin
            )
        }

        return signatures
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
    private func once(_ documents: [Place.Document], held: Set<Identity> = []) throws {
        var held = held

        for document in documents {
            guard let identity = document.identity else { continue }
            guard held.insert(identity).inserted else {
                throw BuildError(
                    "this document was handed to the build twice. A build states"
                        + " its whole graph once, so a document already in it is"
                        + " not something to add",
                    at: Place(in: document)
                )
            }
        }
    }

    // No spelling another document may name declared by two of these. Refused
    // before the order is worked out: the order reads a name as whichever
    // document declared it, and where two declare one name that reading can
    // put a document in its own reach and call the pair a ring.
    private func refuseDoubled(_ modules: [Module], after held: Int) throws {
        var claimed: [Name: Placed<Procedure>] = [:]

        for (position, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key })
            where procedure.access.reachesOtherDocuments {
                let declaration = Placed(
                    procedure,
                    at: .procedure(name.spelling, in: .of(module)),
                    of: held + position
                )

                if let first = claimed[name] {
                    throw BuildError(
                        "'\(name)' is declared more than once in this link, by"
                            + " \(first.spelled) and \(declaration.spelled). Two declarations"
                            + " of a name have no way to be told apart",
                        at: declaration.place
                    )
                }

                claimed[name] = declaration
            }
        }
    }
}
