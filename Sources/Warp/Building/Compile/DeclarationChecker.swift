//
//  DeclarationChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What the compile refuses about a declaration on its own: a type mention that
// resolves to nothing, and a parameter no call could fit.
struct DeclarationChecker {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The type table of a namespace, and the check that each name a
    // declaration mentions is declared in it. A type name is resolved here for
    // the same reason a procedure name is: unreached code still has to
    // compile, and a signature naming a type nobody declared is a defect
    // whether or not this run walks that way. This judges content: what a
    // declaration holds, not what it is called.
    func types(
        of namespace: TypeNamespace,
        standing documents: [any Declaring],
        numbered linkage: Linkage
    ) throws -> TypeTable {
        let declared = namespace.types

        // A document's types take a run of type rows the way its declarations
        // take a run of table rows, in the order the documents stand, so a
        // document's types are behind the types it names.
        let table = TypeTable(
            types: declared.mapValues(\.held),
            contracts: namespace.contracts.mapValues(\.held),
            standing: documents.flatMap { document in document.types.keys.sorted() },
            of: linkage
        )

        // A name that reaches a type may name itself along the way: `Tree`
        // holding `Array<Tree>` is a type. A name that reaches only names
        // never becomes one, and the lowering says which do, so the refusal
        // reads the lowering rather than walking the names a second way.
        // Refused first, so every walk below through `named` is finite.
        // In name order rather than the rows', so which of two names that
        // name themselves is reported does not follow how the documents were
        // handed over.
        for label in table.loweredTypes.cycling.map({ row in table.loweredTypes.labels[row] }).sorted() {
            guard let declaration = declared[label] else { continue }

            throw BuildError(
                "reaches itself through nothing but names, and a name"
                    + " that only names names never reaches a type",
                at: declaration.place
            )
        }

        // The table is walked whole rather than per module: it arrives
        // carrying where each name was written, and asking a module again
        // would be spelling that a second way.
        for (_, declaration) in declared.sorted { $0.key < $1.key } {
            try mentioned(
                in: declaration.held,
                at: declaration.place,
                parameterized: false,
                resolve: table
            )
        }

        return table
    }

    // Every type a document names, held to being one the link declares. A
    // document is read on its own: what is judged is its own text, and the
    // table is what the whole link declared.
    func judge(_ modules: [Module], in table: TypeTable) throws {
        for module in modules {
            for (name, procedure) in module.procedures.sorted { $0.key < $1.key } {
                try judge(procedure.signature, at: .procedure(name.spelling, in: .of(module)), in: table)

                if procedure.implementation.native != nil {
                    try judge(hostAnswered: procedure.signature, at: .procedure(name.spelling, in: .of(module)), in: table)
                }

                // A closure literal carries a signature the way a declaration
                // does, and unreached code still has to compile, so what the
                // top level is held to, a signature written inline is held to
                // in the same pass, wherever a body buries it.
                if case let .body(block) = procedure.implementation {
                    try judge(subexpressions: block, at: .procedure(name.spelling, in: .of(module)), in: table)
                }
            }

            // A contract's procedures are declarations the way the module's
            // own are, and what a call is judged against is what was judged.
            // Each is answered about the value it takes first, so that value
            // is written `Self`, the type that answers the contract, which a
            // call reads as one type parameter the contract bounds.
            for (contract, procedures) in module.contracts.sorted(by: { $0.key < $1.key }) {
                for (name, asked) in procedures.sorted(by: { $0.key < $1.key }) {
                    let place = Place.contract(contract.spelling, in: .of(module)).key(name.spelling)

                    guard asked.signature.parameters.first?.type == .selfType else {
                        throw BuildError(
                            "takes \(asked.signature.parameters.first?.declared.rendered ?? "nothing") first."
                                + " A contract's procedure takes `Self` first: the value it is"
                                + " answered about, of the type that answers it",
                            at: place.part(.parameters)
                        )
                    }

                    try judge(asked.signature.read(of: contract), at: place, in: table)
                }
            }

            for (name, constant) in module.constants.sorted { $0.key < $1.key } {
                try judge(subexpressions: constant, at: .constant(name.spelling, in: .of(module)), in: table)
            }

            // A module variable saying what it holds is held to the type it
            // says the way a name inside a body is.
            for (name, variable) in module.variables.sorted(by: { $0.key < $1.key }) {
                let place = Place.variable(name.spelling, in: .of(module))

                if let declared = variable.declared {
                    try mentioned(in: declared, at: place, parameterized: false, resolve: table)
                }

                try judge(subexpressions: variable.start, at: place, in: table)
            }
        }
    }

    // MARK: - Private
    // Every type a body mentions, held where it is written: the signatures its
    // closures carry, the types its casts name, and what its names say they
    // hold. A procedure's, a constant's and a variable's body each ask this,
    // reached or not.
    private func judge(subexpressions held: some Traversable, at place: Place, in table: TypeTable) throws {
        let subexpressions = held.subexpressions(at: place)

        for (place, inner) in closures(in: subexpressions) {
            try judge(inner.signature, at: place, in: table)
        }

        for (place, named) in castTypes(in: subexpressions) {
            try judge(cast: named, at: place, in: table)
        }

        // A name saying what it holds is a mention like the other two, and
        // unparameterized: what fills a type parameter is a call filling the
        // slot that names it, and a name inside a body is no such slot.
        for (place, declared) in held.declaring(at: place) {
            try mentioned(in: declared, at: place, parameterized: false, resolve: table)
        }
    }

    // Everything a signature is held to where it is declared: every type it
    // mentions resolves, and every bound it names is declared and single. The
    // facts every consumer of the signature reads instead of re-deriving.
    private func judge(
        _ signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        for (position, parameter) in signature.parameters.enumerated() {
            let here = place.part(.parameters).index(position)

            try mentioned(
                in: parameter.declared.slotUnwrapped,
                at: here,
                parameterized: true,
                resolve: table
            )
        }

        // Two parameters under one name would be one name the body reads
        // two ways.
        for (position, parameter) in signature.parameters.enumerated()
        where signature.parameters[..<position].contains(where: { earlier in earlier.name == parameter.name }) {
            throw BuildError(
                "declares '\(parameter.name)' twice",
                at: place.part(.parameters).index(position)
            )
        }

        try mentioned(
            in: signature.returns ?? .any,
            at: place.part(.returns),
            parameterized: true,
            resolve: table
        )

        try judgeBounds(signature.parameterOccurrences, at: place, in: table)
    }

    // A procedure the host answers calls a procedure it was handed with
    // values, so a parameter that may carry one taking a parameter in place
    // asks for what it could never call. Judged on the type a name declares,
    // wherever the parameter holds it.
    private func judge(
        hostAnswered signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        for (position, parameter) in signature.parameters.enumerated()
        where parameter.declared.lowered(in: table.loweredTypes).carriesProcedureTakingInPlace(in: table.loweredTypes) {
            throw BuildError(
                "takes '\(parameter.name)', which may hold a procedure taking a parameter in place,"
                    + " and a procedure the host answers calls what it is handed with values",
                at: place.part(.parameters).index(position)
            )
        }
    }

    // Everything a cast's type is held to on its spelling alone: the names it
    // mentions resolve, and it names a type there is something to read. Both
    // are answered without knowing what the value reads as, so every cast is
    // held to both, reached or not.
    private func judge(
        cast named: TypeExpression,
        at place: Place,
        in table: TypeTable
    ) throws {
        try mentioned(in: named, at: place, parameterized: true, resolve: table)

        if let refusal = named.resolved(in: table).unreadableClaim {
            throw BuildError(refusal, at: place)
        }
    }

    // A named type may name itself, so this checks that a name resolves rather
    // than walking into what it resolves to.
    //
    // `parameterized` says whether a type parameter written here has a call to
    // fill it. A signature's slots do (the walk into a procedure type turns it
    // on) and a declared type does not: a parameter there would stand for
    // nothing any call ever decides, so it is refused where it is declared,
    // and everything a `named` type can hide is judged here rather than at the
    // sites that name it.
    private func mentioned(
        in type: TypeExpression,
        at place: Place,
        parameterized: Bool,
        resolve table: TypeTable
    ) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .string:
            return

        // The build's own note to itself, written where a declaration goes. A
        // declaration is a promise, and this is a type worked out from a body.
        // Nobody promised it, and no document could have spelled it. It is
        // refused here rather than left to the reader, because a reader is one
        // way a declaration is built and a host assembling one is another.
        case let .projection(of, path):
            throw BuildError(
                "writes `\(type.rendered)`, which is a type the build"
                    + " read out of a body. A declaration says what a call fills,"
                    + " and `\(Path([.key(of)] + path.segments).rendered)` is a path"
                    + " only that body can read",
                at: place
            )

        // A contract's procedures read `Self` as the type answering the
        // contract before they are judged, so one standing here stands
        // where nothing answers one.
        case .selfType:
            throw BuildError(
                "writes `Self`, which stands for the type that answers a contract"
                    + " and is written in that contract's procedures alone",
                at: place
            )

        case .parameter:
            guard parameterized else {
                throw BuildError(
                    "writes `\(type.rendered)`, and nothing here is"
                        + " filled by a call. A type parameter lives in a signature",
                    at: place
                )
            }

        // The flag rides through rather than turning on: a procedure type in a
        // signature's slot is part of that signature, and one in a declared
        // type is not a filling site. A parameter written there is never bound
        // at any call, so the bound it claims would be a claim nothing judges.
        case let .procedure(type, _, _):
            guard let type else { return }

            for (position, parameter) in type.parameters.enumerated() {
                try mentioned(
                    in: parameter.slotUnwrapped,
                    at: place.index(position),
                    parameterized: parameterized,
                    resolve: table
                )
            }

            try mentioned(
                in: type.returns ?? .any,
                at: place,
                parameterized: parameterized,
                resolve: table
            )

            try judgeBounds(type.parameterOccurrences, at: place, in: table)

        // A value of whatever type answers every name: each has to be a
        // contract's, since a type is one thing and not a bound on some
        // other.
        case let .composition(names):
            guard !names.isEmpty, Set(names).count == names.count, names == names.sorted() else {
                throw BuildError(
                    "joins \(names.isEmpty ? "nothing" : Set(names).count == names.count ? "names out of order" : "one name twice")"
                        + " with `&`, and a composition names what a value answers, each once and in name order",
                    at: place
                )
            }

            for name in names where table.contracts[name] == nil {
                throw BuildError(
                    "joins '\(name)' with `&`, and `&` joins the names of contracts,"
                        + " which no module in this link declares '\(name)' as",
                    at: place
                )
            }

        // Types and contracts are two tables and no name is in both, so a
        // mention reaches whichever declares it. A contract standing here is
        // a value of whatever type answers it.
        case let .named(name):
            guard table.types[name] != nil || table.contracts[name] != nil else {
                throw BuildError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

        case let .array(element), let .dictionary(element):
            try mentioned(in: element, at: place, parameterized: parameterized, resolve: table)

        // The reader refuses a `?` that says nothing new, but the reader sees
        // spellings, and a name may hide one of the refused types behind it.
        // The rule is the model's, so it is held here too, where names resolve:
        // whatever surface wrote the type, `?` wraps only what does not already
        // answer the null question.
        case let .nullable(inner):
            var resolved = inner

            while case let .named(next) = resolved, let underneath = table.types[next] {
                resolved = underneath
            }

            switch resolved {
            case .any, .null, .never, .parameter, .nullable:
                throw BuildError(
                    "writes `?` on \(inner.rendered), which"
                        + " stands for `\(resolved.rendered)`. A `?` says"
                        + " nothing there, the same rule the spelling"
                        + " `\(resolved.rendered)?` is refused by",
                    at: place
                )

            default:
                break
            }

            try mentioned(in: inner, at: place, parameterized: parameterized, resolve: table)

        // A field written `var` is a fact about a declared type: a path may
        // write through it. A record written inline in a signature declares no
        // type, so it has no field to make writable.
        case let .record(fields):
            for (name, field) in fields.sorted { $0.key < $1.key } {
                var held = field

                if case let .variable(inner) = field, !parameterized {
                    held = inner
                }

                try mentioned(
                    in: held,
                    at: place.part(.fields).key(name.spelling),
                    parameterized: parameterized,
                    resolve: table
                )
            }

        case .inout:
            throw BuildError(
                "writes `\(type.rendered)`, and only a parameter is handed a"
                    + " variable in place. `inout` is written on a parameter's type",
                at: place
            )

        case .variable:
            throw BuildError(
                "writes `\(type.rendered)`, and only a field of a declared type"
                    + " is written through. `var` is written on a field in `types`",
                at: place
            )
        }
    }

    // Every type a cast names in here, however deep, each with where it was
    // found. What the walk holds is `subexpressions`'s to know. This says only which
    // of it a cast scan keeps.
    private func castTypes(
        in subexpressions: [(Place, Expression)]
    ) -> [(Place, TypeExpression)] {
        subexpressions.compactMap { place, expression in
            guard case let .cast(_, named, _) = expression else { return nil }

            return (place, named)
        }
    }

    // Every closure literal in here, however deep, each with where it was
    // found. A closure's own body may hold more of them, and the one walk goes
    // through the one it found.
    private func closures(
        in subexpressions: [(Place, Expression)]
    ) -> [(Place, Procedure)] {
        subexpressions.compactMap { place, expression in
            guard case let .closure(procedure) = expression else { return nil }

            return (place, procedure)
        }
    }

    // Whether a signature's bounded parameters could ever be judged: every
    // name a bound names has to be one somebody declared, and one name is held
    // to one set of them. A bound names a contract. Each occurrence carries
    // its bounds separately, so occurrences carrying different sets for one
    // name are two claims about one thing.
    private func judgeBounds(
        _ occurrences: [ParameterOccurrence],
        at place: Place,
        in table: TypeTable
    ) throws {
        // How each mention is written is judged mention by mention, so no
        // one of them stands for the others.
        var misspelled: Set<Name> = []

        for occurrence in occurrences {
            let names = occurrence.bounds

            if Set(names).count != names.count || names != names.sorted() {
                misspelled.insert(occurrence.name)
            }
        }

        if let misspelled = misspelled.min() {
            throw BuildError("`some \(misspelled)` names its bounds once each and in name order", at: place)
        }

        let bounds = ParameterBounding(occurrences)

        if let refusal = bounds.refusal {
            throw BuildError(refusal, at: place)
        }

        for (parameter, names) in bounds.table.sorted(by: { $0.key < $1.key }) {
            for bound in names where table.contracts[bound] == nil {
                throw BuildError(
                    "`some \(parameter)` names '\(bound)', which no module in this"
                        + " link declares as a contract",
                    at: place
                )
            }
        }
    }
}
