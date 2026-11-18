//
//  Builder.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this link was given and returns an image, or
// refuses.
//
// A build is handed its whole module graph at once. The procedures a program
// can call are the procedures the host put in front of it, so what to build is
// the host's statement and joining the names up is this. A module's `imports`
// says what it asks for and never where to find it. Which declaration a run
// starts from is the run's argument: an image is every declaration the link
// judged, and a host starts a run from any public one.
//
// Every declaration is judged. A misspelled procedure in an arm today's
// arguments never take is a defect whether or not a run walks that way, and so
// is one in a declaration no run calls.
//
// Every call goes through the same gate: a native procedure and one another
// document wrote are checked against their declarations by the same code.
//
// A name is its declared spelling and nothing else. A call site says
// `Standard.Math.floored`, and that is the one declaration it can mean,
// wherever it was written; the image the executor runs is spelled the way the
// documents were, so a run never has to ask again. Constants fold here:
// compiling turns a read of one into its value wherever the run has nothing
// left to decide.
//
// Two stages. Compiling (`Compiler`, one document at a time) judges
// everything a document says against the interfaces it reaches: its
// declarations (`DeclarationChecker`), what it claims (`ClaimChecker`), what
// each body does against what it declares (`EffectChecker`), its bodies
// (`TypeChecker`) and lowering (`Lowering`). It runs the procedures a
// constant calls, which is what folding is. Linking takes what that
// returned, judges what only the whole list can decide, one claim for each
// type and contract, and runs nothing.
public struct Builder: Sendable {
    // MARK: - Property
    // How a compiled document's fingerprint is worked out, where a host wants
    // its objects to say what they are true against: over its object, or over
    // its interface, where a body that is not const may change without the
    // documents leaning on it changing, so long as it names what it named.
    // One that cannot be written down (`ObjectUnwritable`) has no
    // fingerprint.
    //
    // Taken rather than done here. A fingerprint is about bytes, and what
    // writes bytes is another package: this one is the language and does not
    // know how a value is laid down. A host that never caches an object
    // hands nothing over and is handed objects that say they cannot be
    // cached, which is what they are.
    private let fingerprinting: (@Sendable (Compiled) throws -> Fingerprint)?

    // MARK: - Initializer
    public init(fingerprinting: (@Sendable (Compiled) throws -> Fingerprint)? = nil) {
        self.fingerprinting = fingerprinting
    }

    // MARK: - Public
    // Compiling and then linking, which is what building is.
    //
    // What to build is the host's statement, the whole graph at once. A
    // bundled vocabulary is one of those modules, and a document sending a
    // procedure of one the host left out is refused by name.
    public func build(_ modules: [Module]) async throws -> Image {
        try await link(compile(modules), supplying: Supplying(modules))
    }

    // Documents compiled and handed back, for a host that means to build
    // them more than once.
    //
    // A build does two things: it works out what each document says, and it
    // lays the documents down together. The first is a function of the
    // document and of what it reaches, so a host holding the result can hand
    // it over instead of asking for it again. The vocabulary a host brings is
    // the same documents every run, and this is how it stops paying for them
    // every run.
    //
    // The order is worked out here. What a document reaches is read off the
    // procedures it sends and the types and contracts it names, none of which
    // a host wrote down, so a host has nothing to sort by.
    public func compile(_ modules: [Module]) async throws -> [Compiled] {
        try await compile(modules, against: [], supplying: .none)
    }

    // The same, against documents the host already holds.
    //
    // `compiled` is what the host already holds, and the documents given
    // here are compiled against it. A procedure a document sends resolves to
    // either, and one that nothing here declares is refused where it is sent.
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

    // The same, reading back the objects the host cached where they are still
    // true.
    //
    // Each document is asked of `cached` by its identity and what it would
    // be compiled against, where the compile reaches it. An object handed back
    // stands where it was compiled against exactly that; otherwise the
    // document is compiled. An object handed back that does not read is
    // refused, as any object is.
    public func compile(
        _ modules: [Module],
        against compiled: [Compiled],
        supplying natives: Supplying,
        reading cached: (Identity, [Fingerprint]) throws -> Value?
    ) async throws -> [Compilation] {
        try await BuildRefused.refusing {
            try await compile(modules, against: try lay(compiled, supplying: natives), reading: cached, answering: nil)
        }
    }

    // Documents already compiled, with the rows they stand as made once, so a
    // host compiling against them more than once pays for that once.
    //
    // What it costs is every declaration behind the one being compiled: its
    // signature lowered into slots, and for a native the host's procedure
    // joined to it under its spelling. A host brings the same vocabulary every
    // run, and this is where it stops turning it into rows every time.
    public func lay(_ compiled: [Compiled], supplying natives: Supplying) throws -> Laid {
        try BuildRefused.refusing {
            guard !compiled.isEmpty else { return .none }

            try refuseRepeated(compiled.map(\.document))
            try refuseMissingDependencies(compiled)

            // Laid end to end through the door a link lays documents through, so a
            // name two of them declare is refused here as it is there.
            let assembled = try Assembled(compiled)
            let linkage = Linkage()
            let namespace = try TypeNamespace(compiled)

            try ModuleGraph.stand(compiled)

            let declaring = namespace.table(standing: compiled, numbered: linkage)

            let signatures = signatures(of: assembled)

            // Which types conform to which contracts among these documents, each of
            // whose claims was held where its document was compiled.
            let lowered = try ClaimChecker().lowered(declaring, holding: namespace.claims, in: namespace, among: signatures)

            var compiling = Compiling(
                concealing: assembled.concealed,
                types: lowered.types,
                contractProcedures: lowered.contractProcedures,
                naming: compiled.map(\.document),
                spelling: compiled.map(\.naming)
            )

            for (origin, document) in compiled.enumerated() {
                try compiling.lay(document, at: origin, supplied: natives)
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
    }

    // The same, against documents a host already laid down.
    public func compile(_ modules: [Module], against laid: Laid) async throws -> [Compiled] {
        try await BuildRefused.refusing {
            try await compile(modules, against: laid, reading: { _, _ in nil }, answering: nil).map(\.object)
        }
    }

    // What the expression at a place was judged to hold by a build of
    // `modules` against `laid`. Nil where the build judged no expression
    // there. What an expression holds is read off what the walk judging its
    // body passed before reaching it, so a refusal the build meets before the
    // walk reaches the place refuses this, and one it meets after leaves the
    // answer standing.
    package func expressionType(
        where asks: @escaping (Place) -> Bool,
        of modules: [Module],
        against laid: Laid
    ) async throws -> ExpressionType? {
        let query = ExpressionTypeQuery(where: asks)

        do {
            _ = try await BuildRefused.refusing {
                try await compile(modules, against: laid, reading: { _, _ in nil }, answering: query)
            }
        } catch let refused as BuildRefused {
            guard let answer = query.answer else { throw refused }

            return answer
        }

        return query.answer
    }

    // Documents compiled against documents a host laid down, or read back
    // from `cached`, judging asked to answer `query`.
    func compile(
        _ modules: [Module],
        against laid: Laid,
        reading cached: (Identity, [Fingerprint]) throws -> Value?,
        answering query: ExpressionTypeQuery?
    ) async throws -> [Compilation] {
        let compiled = laid.compiled

        try refuseRepeated(modules.map(Place.Document.of), held: laid.identities)

        try refuseDoubled(modules, beside: laid.signatures, after: laid.compiled.count)

        let namespace = try TypeNamespace(compiled + modules)
        let standing = try ModuleGraph(modules, after: compiled.count).standing
        let lowered = try await compile(
            modules,
            at: standing,
            over: namespace,
            against: laid,
            reading: cached,
            answering: query
        )

        // Back in the order the documents were handed over. A document says
        // nothing about where it stands, so the order a link reads them in is
        // the host's.
        var ordered = lowered

        for (position, origin) in standing.enumerated() {
            ordered[origin] = lowered[position]
        }

        return ordered
    }

    // Documents laid down one at a time, in the order `standing` gives, each
    // against the ones already compiled and the ones laid before it.
    //
    // The type tables of a link are its documents' together, read once here.
    // Which types conform to a contract is asked of each document with the claims
    // made within its reach, so what a document compiles to is a fact of it
    // and of what it stands on, however the host split the documents between
    // compiles.
    func compile(
        _ modules: [Module],
        at standing: [Int],
        over namespace: TypeNamespace,
        against laid: Laid,
        reading cached: (Identity, [Fingerprint]) throws -> Value?,
        answering query: ExpressionTypeQuery?
    ) async throws -> [Compilation] {
        let compiled = laid.compiled
        let laying = standing.map { position in modules[position] }
        let documents: [any Declaring] = compiled + laying

        let declaring = namespace.table(standing: documents, numbered: laid.linkage)

        // Every declaration these documents are compiled beside, by the
        // spelling it was declared by: what the documents behind them left on
        // their rows, and what they wrote themselves. No spelling is in it
        // twice, which was refused before the order was worked out.
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
                signatures[symbol.declared] = Placed(
                    Declared(signature: symbol.procedure.signature, access: symbol.procedure.access),
                    at: symbol.place,
                    of: symbol.handed
                )
            }
        }

        // The spellings only a private declaration wears, of every document
        // this compile stands beside or lays down, known before any of them
        // is compiled: why a spelling reaches nothing is a fact of the whole
        // list, and the order the documents are compiled in has no say in it.
        let concealed = laid.carried.concealed.union(holding.flatMap { symbols in
            symbols.filter { symbol in !symbol.supplies }.map(\.declared)
        })

        // The table before any claim, which every document's own is made
        // from. What a contract asks and which spellings it takes are the
        // declarations' alone.
        let unclaimed = try ClaimChecker().lowered(
            declaring,
            holding: [],
            in: namespace,
            among: signatures,
            holdsEveryClaim: false
        )

        // A document never written down is told from another by this compile
        // of it, so each is given that here and carries it out.
        let tokens = laying.map { _ in Compiled.Token() }
        var compiling = Compiling(
            laid.carried,
            concealing: concealed,
            types: unclaimed.types,
            contractProcedures: unclaimed.contractProcedures,
            naming: documents.map(\.document),
            spelling: laid.naming + zip(laying, tokens).map { module, token in
                Closure.Document(identity: module.identity, token: token)
            }
        )

        // What each document turned out to be, as they are laid down. A
        // document laid here may be what the next one stands on, and what it
        // stood on is part of what it is, so the two grow together.
        var declarers = laid.declarers
        var built: [Compilation] = []

        // What each document declares to the others and which of them it
        // stands on, by the place it stands at: the ones declaring what it
        // names, read off its object where it is compiled already, so how the
        // host split the documents between compiles changes nothing. Where
        // the host put each, which is what a claim and a member say of the
        // document making them.
        //
        // A claim a document imports is the claim itself, every copy of it
        // the list holds, and not what the documents making it stand on: the
        // copies are one claim, so what it says is the same whichever of
        // them the host compiled it beside.
        let supplied = compiled.map(\.supplies) + laying.map(\.supplies)
        let named = (compiled.map(\.references) + laying.map(\.references)).map { references in
            references.filter { reference in
                if case .claim = reference { false } else { true }
            }
        }
        let standingOn = named.map { reaches in
            Set(supplied.indices.filter { other in !supplied[other].isDisjoint(with: reaches) })
        }
        let handed = Array(compiled.indices) + standing.map { position in compiled.count + position }

        // Where each document the host handed over stands here, so what a
        // claim or a member says of its document is read as a place a reach
        // holds.
        let standsAt = Dictionary(uniqueKeysWithValues: handed.enumerated().map { position, handed in (handed, position) })
        let claimStands = namespace.claims.map { claim in standsAt[claim.handed] }

        // The members each document gives, which are what a claim is held to
        // and so the declarations whose facts a later claim reads.
        let givenHere = namespace.members.reduce(into: [Int: Set<Name>]()) { given, member in
            given[member.value, default: []].insert(member.key)
        }

        // A claim imported is one some document makes, as a name imported is
        // one some document declares.
        let pairs = namespace.claims.map { claim in ClaimPair(claim.held.type, claim.held.contract) }
        let made = Set(
            namespace.claims.indices
                .filter { index in namespace.claims[index].handed != Prelude.handed }
                .map { index in pairs[index] }
        )

        // The table each set of claims gives, by where the claims
        // stand in the namespace.
        var tables: [[Int]: TypeTable] = [:]

        // What a document laid down declares, as its rows were worked out.
        func declare(_ object: Compiled, at own: Int) {
            for (name, declared) in Self.declarations(
                of: object,
                at: own,
                satisfying: givenHere[own] ?? []
            ) where signatures[name] != nil {
                signatures[name] = declared
            }
        }

        for offset in laying.indices {
            let position = compiled.count + offset
            let reached = Self.reach(of: position, standingOn: standingOn)

            if let unmade = laying[offset].importedClaims.sorted().first(where: { pair in !made.contains(pair) }) {
                let claims = Place([.part(.importedClaims)], in: .of(laying[offset]))

                // A case's spelling is no type, so no document makes a
                // claim about one.
                if declaring.loweredTypes.declaresCase(unmade.type) {
                    throw BuildError(
                        "imports the claim '\(unmade.spelling)', and '\(unmade.type)' names a case: \(Validator.caseIsNoType)",
                        at: claims
                    )
                }

                throw BuildError("imports the claim '\(unmade.spelling)', and no document in this link makes it", at: claims)
            }

            // What the document asks of a contract is decided by the claims
            // made within its reach, the language's among them. Documents
            // standing on the same claims ask the same table.
            let imported = reached.reduce(into: Set<ClaimPair>()) { imported, stood in
                imported.formUnion(documents[stood].importedClaims)
            }
            let claimed = namespace.claims.indices.filter { index in
                claimStands[index].map(reached.contains) ?? (namespace.claims[index].handed == Prelude.handed)
                    || imported.contains(pairs[index])
            }
            let claimedTypes = try tables[claimed] ?? ClaimChecker().satisfying(
                declaring,
                holding: claimed.map { index in namespace.claims[index] },
                in: namespace,
                holdsEveryClaim: false
            )

            tables[claimed] = claimedTypes

            compiling.replace(types: claimedTypes)

            // What a document was compiled against is known once what it
            // stands on is laid down, which is here. An object read back was
            // judged against exactly that, so it is laid down as it was
            // written, its module bringing the code of what it declares
            // native, and judged no further.
            if let object = try read(laying[offset], from: cached, against: declarers) {
                try compiling.lay(object, at: position, supplied: try Supplying([laying[offset]]))
                try compiling.resolve(laidAt: position)

                declare(object, at: handed[position])
                declarers.lay(object)
                built.append(.read(object))

                continue
            }

            try DeclarationChecker().judge([laying[offset]], in: claimedTypes)

            let object = try await Compiler(
                foldingThrough: Self.witnesses(of: reached, supplied: supplied),
                answering: query
            ).compile(
                laying[offset],
                at: position,
                declaring: holding[offset],
                against: declarers.dependencies(of: laying[offset]),
                as: tokens[offset],
                in: &compiling
            )

            // What it claims and extends, held now that its rows stand, so a
            // claim backed by its own members meets what they were worked out
            // to be.
            let own = handed[position]

            declare(object, at: own)

            let claims = namespace.claims.filter { claim in claim.handed == own }
            let extended = namespace.extended.filter { extended in extended.handed == own }

            if !claims.isEmpty || !extended.isEmpty {
                try ClaimChecker().judge(
                    claims,
                    extending: extended,
                    by: laying[offset],
                    in: namespace,
                    members: Set(namespace.members.filter { _, giver in standsAt[giver].map(reached.contains) ?? false }.keys),
                    typeMembers: Set(namespace.typeMembers.filter { _, given in
                        standsAt[given.handed].map(reached.contains) ?? false
                    }.keys),
                    among: signatures,
                    in: claimedTypes
                )
            }

            let known = try fingerprinted(object)

            declarers.lay(known)
            built.append(.compiled(known))
        }

        return built
    }

    // The documents laid down as one table of rows. Nothing runs here: every
    // declaration stands compiled already, and the rows are relocated into
    // this link's numbering.
    //
    // What is judged here is what no document could decide about itself, the
    // facts only the documents taken together hold. `supplying` is the native
    // code the documents named. An object says which of its
    // procedures are native and holds none of the code, so the modules that
    // declared them are handed over beside the objects.
    public func link(
        _ compiled: [Compiled],
        supplying natives: Supplying
    ) throws -> Image {
        try BuildRefused.refusing {
            try refuseRepeated(compiled.map(\.document))
            try refuseMissingDependencies(compiled)

            // Every document's block laid down, which is where its rows first
            // stand somewhere. What a name reaches is resolved from here on.
            let assembled = try Assembled(compiled)

            // The types of this link, made from what its documents declared and
            // laid down in the order their blocks are. Which types conform to which
            // contracts is read across the documents, so the rows a body stands on
            // are resolved here rather than carried out of a compile.
            let namespace = try TypeNamespace(compiled)

            // Each object stands after what it names, the order the documents it
            // was compiled from stood in.
            try ModuleGraph.stand(compiled)

            let declaring = namespace.table(standing: compiled, numbered: Linkage())

            let signatures = signatures(of: assembled)

            // Which types conform to which contracts across the documents, one claim
            // each, every one of them held where its document was compiled.
            let lowered = try ClaimChecker().lowered(declaring, holding: namespace.claims, in: namespace, among: signatures)
            let types = lowered.types

            // The documents' own numbers turned into this link's rows, and the
            // calls through a contract filled with the rows that satisfy them.
            let relocating = try Relocating(
                assembled,
                types: types,
                contractProcedures: lowered.contractProcedures,
                supplied: natives
            )
            let linked = try relocating.linked()
            let variables = try relocating.started(assembled.variables)

            return Image(
                linked: linked.table,
                rows: assembled.rows,
                concealed: assembled.concealed,
                types: types,
                variables: variables,
                naming: assembled.naming,
                contractProcedures: lowered.contractProcedures
            )
        }
    }

    // MARK: - Private
    // The documents the one at `origin` stands on, near or far, and itself.
    private static func reach(of origin: Int, standingOn: [Set<Int>]) -> Set<Int> {
        var reached: Set<Int> = [origin]
        var waiting = [origin]

        while let next = waiting.popLast() {
            for other in standingOn[next] where reached.insert(other).inserted {
                waiting.append(other)
            }
        }

        return reached
    }

    // The declarations a fold may run where it calls through a contract:
    // those of every document within the reach of the one folding, since a
    // body it runs may run one of theirs.
    private static func witnesses(of reached: Set<Int>, supplied: [Set<Reference>]) -> Set<Name> {
        Set(reached.flatMap { position in
            supplied[position].compactMap { reference -> Name? in
                guard case let .procedure(name) = reference else { return nil }

                return name
            }
        })
    }

    // What one object's members say of themselves, under the spelling each
    // was declared by: what a claim is held to.
    private static func declarations(
        of object: Compiled,
        at handed: Int,
        satisfying members: Set<Name>
    ) -> [Name: Placed<Declared>] {
        guard !members.isEmpty else { return [:] }

        return object.declared.enumerated().reduce(into: [:]) { declarations, entry in
            let (offset, name) = entry

            guard members.contains(name) else { return }

            let judged = object.table[offset]

            declarations[name] = Placed(
                Declared(signature: judged.signature, access: judged.access),
                at: Place.procedure(name.spelling, in: object.document),
                of: handed
            )
        }
    }

    // The object the host cached for a document, read back, where it was
    // compiled against what the document would be compiled against now.
    private func read(
        _ module: Module,
        from cached: (Identity, [Fingerprint]) throws -> Value?,
        against declarers: DeclarerTable
    ) throws -> Compiled? {
        guard let identity = module.identity,
            let dependencies = declarers.dependencies(of: module),
            let object = try cached(identity, dependencies)
        else {
            return nil
        }

        let read = try Compiled(written: object, of: identity)

        guard read.dependencies == dependencies else { return nil }

        return try fingerprinted(read)
    }

    // Every object standing beside what it was compiled against. An object
    // says what it leaned on by fingerprint, and what it worked out, a closure
    // spelled by a document's name and count among them, is true against
    // exactly those compiles of them. A document that leaned on nothing a
    // fingerprint was worked out for says nothing here. One that did is
    // held to it, document by document: what it leaned on stands beside it
    // under the fingerprint it had then, or the document is not laid.
    private func refuseMissingDependencies(_ compiled: [Compiled]) throws {
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

    // An object said as what it is, where the host handed over how that is
    // worked out. One that cannot be written down has nothing to work it out
    // from, which is the same absence said one step earlier. Why is
    // `object()`'s to say, to a host that asks for the object.
    private func fingerprinted(_ object: Compiled) throws -> Compiled {
        guard let fingerprinting else { return object }

        do {
            return object.fingerprinted(try fingerprinting(object))
        } catch is ObjectUnwritable {
            return object
        }
    }

    // Every declaration the documents laid down made, under the spelling it
    // was declared by and at the place it was written. What a document
    // declares is its own; where it stands among the documents is the
    // host's order.
    private func signatures(of assembled: Assembled) -> [Name: Placed<Declared>] {
        var signatures: [Name: Placed<Declared>] = [:]

        for (name, number) in assembled.rows {
            let row = assembled.table[number]

            signatures[name] = Placed(
                Declared(signature: row.judged.signature, access: row.judged.access),
                at: Place.procedure(name.spelling, in: assembled.documents[row.origin]),
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
    // fix is not a spelling but a host holding what it already had.
    //
    // What the host already compiled counts: those documents are in this
    // link too, and handing one over again is the same document twice however
    // it arrived.
    private func refuseRepeated(_ documents: [Place.Document], held: Set<Identity> = []) throws {
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

    // No spelling another document may name declared twice: by two of these,
    // or by one of these and one laid before them. Refused before the order
    // is worked out: the order reads a name as whichever document declared
    // it, and where two declare one name that reading can put a document in
    // its own reach and call the pair a cycle. A doubled spelling is not a
    // question of which document to read first, it is a table that cannot say
    // which row that name is.
    //
    // `signatures` are the declarations of the documents laid before these,
    // and `count` how many of them stand there.
    private func refuseDoubled(
        _ modules: [Module],
        beside signatures: [Name: Placed<Declared>],
        after count: Int
    ) throws {
        var claimed = signatures.mapValues(\.spelled)

        for (position, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key })
            where procedure.access.reachesOtherDocuments {
                let declaration = Placed(
                    procedure,
                    at: .procedure(name.spelling, in: .of(module)),
                    of: count + position
                )

                if let first = claimed[name] {
                    throw BuildError.declaredTwice(name, by: first, and: declaration.spelled, at: declaration.place)
                }

                claimed[name] = declaration.spelled
            }
        }
    }
}
