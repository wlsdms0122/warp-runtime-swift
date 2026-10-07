//
//  DeclarationChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What the compile refuses about a declaration on its own: a type mention that
// resolves to nothing, a parameter no call could fit, and a constraint no value
// satisfies.
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
        let members = namespace.constraints

        // A document's types and its memberships each take a run of type rows
        // the way its declarations take a run of table rows, in the order the
        // documents stand, so a document's types are behind the types it names.
        let table = TypeTable(
            types: declared.mapValues(\.held),
            constraints: members.mapValues(\.held),
            contracts: namespace.contracts.mapValues(\.held),
            standing: documents.flatMap { document in document.types.keys.sorted() },
            constraintStanding: documents.flatMap { document in document.constraints.keys.sorted() },
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

        for (_, declaration) in members.sorted { $0.key < $1.key } {
            let admitted = declaration.held

            guard !admitted.isEmpty else {
                throw BuildError(
                    "admits nothing, so no parameter it"
                        + " bounds could ever be filled",
                    at: declaration.place
                )
            }

            // A member is a concrete type. `some` stands for a type and names
            // none, `Any` would admit everything a membership exists to narrow,
            // and `Never` admits nothing. Each is a declaration that says
            // nothing a membership could hold. Judged through every name a
            // member hides behind, or one alias would carry the refused type
            // in. The chain is finite because a name-only cycle was refused
            // above.
            for member in admitted {
                var resolved = member

                while case let .named(next) = resolved, let underneath = declared[next] {
                    resolved = underneath.held
                }

                // A name left standing names no declared type: another
                // membership, which is a set of types and stands; a
                // contract, which is not a type; or nothing, which the
                // mention below refuses by its own name.
                let concrete = switch resolved {
                case let .named(name): namespace.contracts[name] == nil
                case .parameter, .any, .never, .composition, .selfType: false
                case .null, .bool, .int, .double, .string, .ranged, .array,
                    .dictionary, .record, .procedure, .variable, .inout, .linear, .consuming,
                    .borrowing, .nullable, .projection: true
                }

                guard concrete else {
                    throw BuildError(
                        "a member is a concrete type."
                            + " `\(member.rendered)` says nothing a"
                            + " membership could hold",
                        at: declaration.place
                    )
                }
            }
        }

        // The two tables are walked whole rather than per module:
        // they arrive carrying where each name was written, and asking a module
        // again would be spelling that a second way.
        for (_, declaration) in declared.sorted { $0.key < $1.key } {
            try mentioned(
                in: declaration.held,
                at: declaration.place,
                parameterized: false,
                declaring: true,
                resolve: table
            )
        }

        for (_, declaration) in members.sorted { $0.key < $1.key } {
            for member in declaration.held {
                try mentioned(
                    in: member,
                    at: declaration.place,
                    parameterized: false,
                    resolve: table
                )
            }
        }

        return table
    }

    // Every type a document names, held to being one the link declares. A
    // document is read on its own: what is judged is its own text, and the
    // table is what the whole link declared.
    func judge(_ modules: [Module], in table: TypeTable) throws {
        try judge(memberships: modules, in: table)

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

            for (name, variable) in module.variables.sorted { $0.key < $1.key } {
                try judge(subexpressions: variable.start, at: .variable(name.spelling, in: .of(module)), in: table)
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
            try judge(carried: inner.signature.type, at: place, in: table)
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
    // mentions resolves, every parameter could be filled, and every constraint
    // it names is declared and single. The facts every consumer of the
    // signature reads instead of re-deriving.
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
            try saysWhatItDoes(with: parameter.declared, at: here, in: table)
            try judge(parameter, at: here, in: table)
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

        try judgeConstraints(signature.parameterOccurrences, at: place, in: table)
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

    // Whether a parameter's own declaration can be satisfied at all. Facts it
    // states about itself, judged wherever a parameter is written: an `enum`
    // none of whose candidates the declared type admits is a parameter no call
    // could ever fit.
    private func judge(
        _ parameter: Parameter,
        at place: Place,
        in table: TypeTable
    ) throws {
        // The declaration as the boundary reads it, so what the build calls
        // dead is exactly what the boundary would never match.
        let type = parameter.declared.lowered(in: table.loweredTypes)

        if let allowed = parameter.candidates {
            // Candidate by candidate: a spelling the declared type cannot spell
            // is a member no call could ever match, and a dead member is the
            // declaration's own defect whether live ones stand beside it or
            // not. One pass reads both facts. A list that is empty or entirely
            // dead refuses by the plainer name, a dead member among live ones
            // is named.
            let dead = allowed.filter { candidate in
                !type.spells(candidate, in: table.loweredTypes)
            }

            if dead.count == allowed.count {
                throw BuildError(
                    "enum admits nothing, so no call could ever fit",
                    at: place
                )
            }

            if let first = dead.first {
                throw BuildError(
                    "enum lists '\(first)', which"
                        + " \(parameter.declared.rendered) does not admit."
                        + " No call could ever match it",
                    at: place
                )
            }
        }
    }

    // A named type may name itself, so this checks that a name resolves rather
    // than walking into what it resolves to.
    //
    // `parameterized` says whether a type parameter written here has a call to
    // fill it. A signature's slots do (the walk into a procedure type turns it
    // on) and a declared type or a constraint member does not: a parameter
    // there would stand for nothing any call ever decides, so it is refused
    // where it is declared, and everything a `named` type can hide is judged
    // here rather than at the sites that name it.
    private func mentioned(
        in type: TypeExpression,
        at place: Place,
        parameterized: Bool,
        declaring: Bool = false,
        nested: Bool = false,
        resolve table: TypeTable
    ) throws {
        // A value handed on once is followed by the name that holds it, so
        // it stands where a name can hold it and nowhere else. Inside another
        // type there is no name to follow, and what the type does with what
        // it carries is not something the build can read.
        guard !nested || !type.handedOnce(in: table) else {
            throw BuildError(
                "carries '\(type.rendered)' inside another type, and a value written"
                    + " `linear` is followed by the name that holds it."
                    + " Nothing follows one inside a list, a record or"
                    + " another declaration",
                at: place
            )
        }

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

        // The bounds are the declaration's own claim, so an order the numbers
        // refuse is refused where it was written. A range below its own floor
        // is a slot no call could ever fit, the way an empty `enum` is.
        case let .ranged(refinement):
            if refinement.saysNothing {
                throw BuildError(
                    "writes `\(type.rendered)` with neither bound."
                        + " A range that says nothing is spelled"
                        + " `\(refinement.kind.rendered)`",
                    at: place
                )
            }

            if refinement.admitsNothing {
                throw BuildError(
                    "writes `\(type.rendered)`, which admits nothing."
                        + " No \(refinement.kind.rendered) is inside it",
                    at: place
                )
            }

            return

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

            try judge(carried: type, at: place, in: table)

            for (position, parameter) in type.parameters.enumerated() {
                try mentioned(
                    in: parameter.slotUnwrapped,
                    at: place.index(position),
                    parameterized: parameterized,
                    nested: nested,
                    resolve: table
                )
            }

            try mentioned(
                in: type.returns ?? .any,
                at: place,
                parameterized: parameterized,
                resolve: table
            )

            try judgeConstraints(type.parameterOccurrences, at: place, in: table)

        // A value of whatever type answers every name: each has to be a
        // membership's or a contract's, since a type is one thing and not a
        // bound on some other.
        case let .composition(names):
            guard !names.isEmpty, Set(names).count == names.count, names == names.sorted() else {
                throw BuildError(
                    "joins \(names.isEmpty ? "nothing" : Set(names).count == names.count ? "names out of order" : "one name twice")"
                        + " with `&`, and a composition names what a value answers, each once and in name order",
                    at: place
                )
            }

            for name in names where table.constraints[name] == nil && table.contracts[name] == nil {
                throw BuildError(
                    "joins '\(name)' with `&`, and `&` joins the names of memberships"
                        + " and contracts, which no module in this link declares '\(name)' as",
                    at: place
                )
            }

        // Types, memberships and contracts are three tables and no name is in
        // two, so a mention reaches whichever declares it. A membership
        // standing here is a value of one of its members, and a contract
        // standing here is a value of whatever type answers it.
        case let .named(name):
            guard table.types[name] != nil || table.constraints[name] != nil || table.contracts[name] != nil else {
                throw BuildError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

        case let .array(element), let .dictionary(element):
            try mentioned(in: element, at: place, parameterized: parameterized, nested: true, resolve: table)

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

            // What a value handed on once needs is a name holding it on every way
            // through, and a `?` says there is a way through where nothing is
            // there. So the mark and the doubt do not stand together.
            guard !inner.handedOnce(in: table) else {
                throw BuildError(
                    "writes `?` on \(inner.rendered), which is handed on exactly"
                        + " once. \(LinearityChecker.followedByAName)",
                    at: place
                )
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
                    nested: true,
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

        // Both say what a slot does with the obligation a `linear` value
        // carries, so both stand where a slot is written and nowhere else. A
        // parameter's own type is stripped of them before it reaches here.
        case .consuming, .borrowing:
            throw BuildError(
                "writes `\(type.rendered)`, and only a parameter says what it does"
                    + " with a value handed on once. `consuming` and `borrowing`"
                    + " are written on a parameter's type",
                at: place
            )

        // Only a declared type is handed on once. The obligation rides with
        // the name, so a slot mentioning the name has it and a slot writing
        // the procedure would be claiming it for a type nothing declared it of.
        case let .linear(inner):
            guard declaring else {
                throw BuildError(
                    "writes `\(type.rendered)`, and only a declared type is"
                        + " handed on once. `linear` is written on a type in `types`,"
                        + " and a slot naming that type carries it",
                    at: place
                )
            }

            try mentioned(in: inner, at: place, parameterized: parameterized, resolve: table)
        }
    }

    // A slot taking a value handed on once says which way it takes it, and one
    // taking anything else says neither. Silence read as taking the obligation
    // is what kept a procedure from reading one without taking it, and a mark
    // where nothing is handed on once is a claim about nothing, refused the way
    // a `?` that says nothing new is.
    private func saysWhatItDoes(
        with declared: TypeExpression,
        at place: Place,
        in table: TypeTable
    ) throws {
        switch declared {
        // The mark names the type, because that is what the build follows the
        // value by. What fills a type parameter or a membership is the call's,
        // so a body taking one there has no name to carry the obligation on
        // and the proof would end at this slot.
        case .consuming, .borrowing:
            guard !declared.slotUnwrapped.handedOnce(in: table) else { return }

            throw BuildError(
                "takes '\(declared.rendered)', and a slot says what it does with a"
                    + " value handed on once by naming the type that is one. No"
                    + " value of the type written here is",
                at: place
            )

        default:
            guard declared.slotUnwrapped.handedOnce(in: table) else { return }

            throw BuildError(
                "takes '\(declared.rendered)', which is handed on once, and says"
                    + " nothing about what it does with it. A parameter taking one"
                    + " writes `consuming` where the obligation moves to it, and"
                    + " `borrowing` where the obligation stays with the caller",
                at: place
            )
        }
    }

    // A body carried as a value, held to what it may answer. What a procedure
    // answers is followed by the name that holds it, and no walk enters a body
    // carried as a value: a closure runs where the text that wrote it cannot
    // see, so what it hands back would arrive with nothing to say it is owed.
    //
    // A declaration is not held to this. Its body is text a walk reads, and
    // what it answers lands on the name its caller binds.
    private func judge(carried type: ProcedureType, at place: Place, in table: TypeTable) throws {
        guard let returns = type.returns, returns.handedOnce(in: table) else { return }

        throw BuildError(
            "writes a procedure answering \(returns.rendered), which is handed on"
                + " exactly once. \(LinearityChecker.followedByAName), and a body carried as a"
                + " value runs where no name is watching",
            at: place
        )
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
    // name a bound names has to be one somebody declared, and one name is
    // held to one set of them. A bound names a membership or a contract, and
    // the two are separate spaces no name is in both of, so a mention reaches
    // whichever declares it. Each occurrence carries its bounds separately,
    // so occurrences carrying different sets for one name are two claims
    // about one thing.
    private func judgeConstraints(
        _ occurrences: [ParameterOccurrence],
        at place: Place,
        in table: TypeTable
    ) throws {
        // How each mention is written is judged mention by mention, so no
        // one of them stands for the others.
        var misspelled: Set<Name> = []

        for occurrence in occurrences {
            let names = occurrence.constraints

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
            for bound in names where table.constraints[bound] == nil && table.contracts[bound] == nil {
                throw BuildError(
                    "`some \(parameter)` names '\(bound)', which no module in this"
                        + " link declares as a membership or a contract",
                    at: place
                )
            }
        }
    }

    // A membership is handed on once when every member is, so one that mixes
    // has no answer: a value of it would carry an obligation on some readings
    // and not on others, and which it was is exactly what a membership does not
    // say.
    //
    // Asked of every module before any procedure is judged, and in name order,
    // because a slot naming such a membership reads its answer off this. A
    // procedure judged first would be told its slot is the mistake, and the
    // mistake is the declaration.
    private func judge(memberships modules: [Module], in table: TypeTable) throws {
        let declared = modules
            .flatMap { module in module.constraints.map { name, members in (name, members, module) } }
            .sorted { one, other in one.0 < other.0 }

        for (name, members, module) in declared {
            let (handed, rest) = members.reduce(into: ([TypeExpression](), [TypeExpression]())) { split, member in
                if member.handedOnce(in: table) {
                    split.0.append(member)
                } else {
                    split.1.append(member)
                }
            }

            guard !handed.isEmpty, !rest.isEmpty else { continue }

            throw BuildError(
                "admits \(handed.map(\.rendered).sorted().joined(separator: " and ")),"
                    + " which is handed on exactly once, beside"
                    + " \(rest.map(\.rendered).sorted().joined(separator: " and ")),"
                    + " which is not. A value of a membership is followed the same"
                    + " way whichever member it is",
                at: .constraint(name.spelling, in: .of(module))
            )
        }
    }
}
