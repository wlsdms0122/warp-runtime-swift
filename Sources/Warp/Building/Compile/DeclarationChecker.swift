//
//  DeclarationChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What the build refuses about declarations once their names resolve: a
// mention no module in the link declares, a bound or a composition naming what
// is no contract, a `?` behind a name where it says nothing, a cast naming
// nothing to read, and a parameter a procedure the host answers could never
// call.
struct DeclarationChecker {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Every type a document names, held to being one the link declares, and
    // every map type it names keyed by a type that answers `Hashable`. A type
    // name is resolved here for the same reason a procedure name is:
    // unreached code still has to compile, and a signature naming a type
    // nobody declared is a defect whether or not a run walks that way. A
    // document is read on its own: what is judged is its own text, and the
    // table is what the link declared, answering with the claims the
    // document stands on.
    func judge(_ modules: [Module], in table: TypeTable) throws {
        for module in modules {
            for (name, declared) in module.types.sorted(by: { $0.key < $1.key }) {
                try mentioned(in: declared, at: .type(name.spelling, in: .of(module)), resolve: table)
            }

            // A head before the members under it, whose signatures carry the
            // head's bounds: a bound is refused where the head writes it.
            try judge(contracts: module.contracts, of: .of(module), in: table)
            try judge(
                heads: Set(module.claims.keys).union(module.members.keys).union(module.typeMembers.keys),
                of: .of(module),
                in: table
            )

            try judge(bareMembers: module.members, of: module, in: table)

            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                try judge(procedure.signature, at: .procedure(name.spelling, in: .of(module)), in: table)

                if procedure.implementation.native != nil {
                    try judge(
                        hostAnswered: procedure.signature,
                        at: .procedure(name.spelling, in: .of(module)),
                        in: table
                    )
                }

                // A closure literal carries a signature the way a declaration
                // does, and unreached code still has to compile, so what the
                // top level is held to, a signature written inline is held to
                // in the same pass, wherever a body buries it.
                if case let .body(body) = procedure.implementation {
                    try judge(
                        subexpressions: body,
                        at: .procedure(name.spelling, in: .of(module)),
                        bounds: procedure.signature.bounds,
                        sameTypes: procedure.signature.sameTypes,
                        in: table
                    )
                }
            }

            try judge(typeMembers: module.typeMembers, of: .of(module), in: table)

            for (name, constant) in module.constants.sorted(by: { $0.key < $1.key }) {
                try judge(subexpressions: constant, at: .constant(name.spelling, in: .of(module)), in: table)
            }

            // A module variable saying what it holds is held to the type it
            // says the way a name inside a body is.
            for (name, variable) in module.variables.sorted(by: { $0.key < $1.key }) {
                let place = Place.variable(name.spelling, in: .of(module))

                if let declared = variable.declared {
                    try mentioned(in: declared, at: place, resolve: table)
                }

                try judge(subexpressions: variable.start, at: place, in: table)
            }
        }
    }

    // MARK: - Private
    // A contract's procedures are declarations the way a document's own are,
    // and what a call is judged against is what was judged. `Self` is read
    // as one type parameter the contract bounds.
    private func judge(
        contracts: [Name: Contract],
        of document: Place.Document,
        in table: TypeTable
    ) throws {
        for (contract, declared) in contracts.sorted(by: { $0.key < $1.key }) {
            let home = Place.contract(contract.spelling, in: document)

            try judge(bounds: declared.bounds, at: { _ in home.part(.types) }, in: table)

            for (name, asked) in declared.procedures.sorted(by: { $0.key < $1.key }) {
                let place = home.part(.procedures).key(name.spelling)

                try judge(asked.read(of: contract), at: place, in: table)
            }
        }
    }

    // A head mentions what it applies its type to the way a parameter's type
    // does, and bounds its own type parameters by contracts somebody
    // declared. A bare head mentions nothing beyond its type, which is the
    // claim's to judge.
    private func judge(
        heads: Set<Head>,
        of document: Place.Document,
        in table: TypeTable
    ) throws {
        for head in heads.sorted() {
            guard let mention = head.mention else { continue }

            let place = Place(document.home(of: head), in: document)

            try mentioned(in: mention, at: place, bounds: head.bounds, resolve: table)

            // A head writes its bounds beside the names, so a bound stands where
            // the head is written.
            try judge(bounds: head.bounds, at: { _ in place }, in: table)
        }
    }

    // A type member mentions what its type names, the way a field does, its
    // head's type parameters held to what the head holds them to.
    // A member under its type's bare name is there for every value of the
    // type, so it takes each first: what a claim under that name reads `Self`
    // as, the type applied to parameters no call fills, held to the bounds the
    // type holds them to. What fills its own parameters there is held to their
    // bounds, as a claim's member is.
    private func judge(bareMembers members: [Head: Set<Name>], of module: Module, in table: TypeTable) throws {
        let loweredTypes = table.loweredTypes

        for (head, names) in members.sorted(by: { $0.key < $1.key }) where head.isBare {
            let applied = head.applying(table.types[head.type]).claimed
            let type = applied?.type ?? TypeExpression.nominalTypes[head.type] ?? .named(head.type)
            let values = type.lowered(in: loweredTypes, bounds: applied?.bounds ?? [:])

            for name in names.sorted() {
                let spelling = name.spelled(under: head.type)

                guard
                    let signature = module.procedures[spelling]?.signature,
                    let first = signature.lowered(in: loweredTypes).first?.type
                else { continue }

                let substitution = Substitution(filling: [first], against: [values], in: loweredTypes)
                let unanswered = signature.bounds.sorted(by: { $0.key < $1.key }).contains { parameter, bounds in
                    substitution.everyReading(of: parameter).contains { reading in
                        !LoweredType.composition(bounds.sorted()).accepts(reading, in: loweredTypes)
                    }
                }

                guard !unanswered, first.filling(substitution.readings).takes(values, in: loweredTypes) else {
                    throw BuildError(
                        "gives '\(head.type)' the member '\(name)', which takes \(first.rendered(in: loweredTypes)) first."
                            + " Under its type's bare name a member takes every value of the type first, and one for"
                            + " some of them is given under a head applying the type",
                        at: Place.procedure(spelling.spelling, in: .of(module)).part(.parameters)
                    )
                }
            }
        }
    }

    private func judge(
        typeMembers: [Head: [Name: TypeExpression]],
        of document: Place.Document,
        in table: TypeTable
    ) throws {
        for member in TypeMember.listed(typeMembers) {
            try mentioned(
                in: member.type,
                at: .typeMember(member, in: document),
                bounds: member.head.applying(table.types[member.head.type]).bounds,
                resolve: table
            )
        }
    }

    // Every type a body mentions, held where it is written: the signatures its
    // closures carry, the types its casts name, and what its names say they
    // hold. A procedure's, a constant's and a variable's body each ask this,
    // reached or not.
    // `bounds` are the declaration's, which every type parameter a body
    // writes is held to.
    private func judge(
        subexpressions held: some Traversable,
        at place: Place,
        bounds: [Name: Set<Name>] = [:],
        sameTypes: [Name: TypeExpression] = [:],
        in table: TypeTable
    ) throws {
        let subexpressions = held.subexpressions(at: place)

        for (place, inner) in closures(in: subexpressions) {
            try judge(inner.signature.bounded(by: bounds, sameTypes: sameTypes), at: place, in: table)
        }

        for (place, named) in castTypes(in: subexpressions) {
            try judge(cast: named, at: place, bounds: bounds, sameTypes: sameTypes, in: table)
        }

        // A name saying what it holds is a mention like the other two.
        for (place, declared) in held.declaring(at: place) {
            try mentioned(in: declared, at: place, bounds: bounds, sameTypes: sameTypes, resolve: table)
        }
    }

    // Everything a signature is held to where it is declared: every type it
    // mentions resolves, and every bound it names is a declared contract. The
    // facts every consumer of the signature reads instead of re-deriving.
    private func judge(
        _ signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        for (position, parameter) in signature.parameters.enumerated() {
            try mentioned(
                in: parameter.type.slotUnwrapped,
                at: place.part(.parameters).index(position),
                bounds: signature.bounds,
                sameTypes: signature.sameTypes,
                resolve: table
            )
        }

        try mentioned(
            in: signature.returns,
            at: place.part(.returns),
            bounds: signature.bounds,
            sameTypes: signature.sameTypes,
            resolve: table
        )

        try judge(bounds: signature.bounds, at: { parameter in place.bound(parameter, of: signature) }, in: table)

        // An associated type the signature bounds or says is a type is one a
        // contract bounding its parameter asks, and the type it is said to be
        // answers what holds it, as a type a call fills it with would.
        for label in Set(signature.bounds.keys).union(signature.sameTypes.keys).sorted() {
            guard let member = label.associated else { continue }

            let at = place.part(signature.sameTypes[label] != nil ? .sameTypes : .bounds).key(label.spelling)

            try mentioned(
                in: .associatedType(of: member.of, name: member.name),
                at: at,
                bounds: signature.bounds,
                resolve: table
            )
        }

        for (label, same) in signature.sameTypes.sorted(by: { $0.key < $1.key }) {
            let at = place.part(.sameTypes).key(label.spelling)

            try mentioned(
                in: same,
                at: at,
                bounds: signature.bounds,
                sameTypes: signature.sameTypes,
                resolve: table
            )

            guard label.associated != nil else { continue }

            let types = table.loweredTypes
            let held = types.contracts(bounding: label, under: signature.bounds)
            let lowered = same.lowered(in: types, bounds: signature.bounds, sameTypes: signature.sameTypes)

            for bound in held.sorted() {
                if let refusal = types.refusal(of: lowered, answering: bound, orNull: false, as: "says '\(label)' is") {
                    throw BuildError(refusal + ", and '\(label)' is held to '\(bound)'", at: at)
                }
            }
        }
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
        where parameter.type.lowered(in: table.loweredTypes).carriesProcedureTakingInPlace(in: table.loweredTypes) {
            throw BuildError(
                "takes '\(parameter.name)', which may hold a procedure taking a parameter in place,"
                    + " and a procedure the host answers calls what it is handed with values",
                at: place.part(.parameters).index(position)
            )
        }
    }

    // Everything a cast's type is held to on its spelling alone: the names it
    // mentions resolve, and what it lowers to is a type there is something to
    // read. Both are answered without knowing what the value reads as, so
    // every cast is held to both, reached or not.
    private func judge(
        cast named: TypeExpression,
        at place: Place,
        bounds: [Name: Set<Name>],
        sameTypes: [Name: TypeExpression],
        in table: TypeTable
    ) throws {
        try mentioned(in: named, at: place, bounds: bounds, sameTypes: sameTypes, resolve: table)

        switch named.lowered(in: table.loweredTypes) {
        case .any:
            throw BuildError(
                "reads as \(TypeSpelling.any), which declares nothing."
                    + " A cast names the type a value is read as, and `Any` is"
                    + " the absence of one",
                at: place
            )

        case .never:
            throw BuildError(
                "reads as \(TypeSpelling.never), which no value is."
                    + " A cast names the type a value turns out to have, and"
                    + " nothing arrives to have this one",
                at: place
            )

        default:
            return
        }
    }

    // A named type may name itself, so this checks that a name resolves rather
    // than walking into what it resolves to. Where each word may stand was
    // held at the load, by the `Validator`.
    private func mentioned(
        in type: TypeExpression,
        at place: Place,
        bounds: [Name: Set<Name>] = [:],
        sameTypes: [Name: TypeExpression] = [:],
        resolve table: TypeTable
    ) throws {
        // A part, judged under the same signature.
        func part(_ type: TypeExpression, at place: Place) throws {
            try mentioned(in: type, at: place, bounds: bounds, sameTypes: sameTypes, resolve: table)
        }

        switch type {
        case .any, .never, .null, .bool, .int, .double, .string, .selfType, .parameter:
            return

        // An associated type is one a contract bounding what it stands on
        // asks, `Self` in a contract's procedures being bounded by that
        // contract, and what it stands on is one too where it is written on
        // another.
        case let .associatedType(of, name):
            if let standing = of.associated {
                try part(.associatedType(of: standing.of, name: standing.name), at: place)
            }

            try asked(name, of: of, at: place, bounds: bounds, in: table)

        case let .procedure(type, _, _):
            guard let type else { return }

            for (position, parameter) in type.parameters.enumerated() {
                try part(parameter.slotUnwrapped, at: place.index(position))
            }

            try part(type.returns, at: place.part(.returns))

        case let .composition(names):
            try joined(names, at: place, in: table)

        // Types and contracts are two tables and no name is in both, so a
        // mention reaches whichever declares it. A contract standing here is
        // a value of whatever type answers it.
        case let .named(name, arguments):
            try declared(name, at: place, in: table)

            for argument in arguments {
                try part(argument, at: place)
            }

            try applied(
                name,
                to: arguments,
                at: place,
                bounds: bounds,
                sameTypes: sameTypes,
                in: table
            )

        case let .array(inner), let .inout(inner), let .variable(inner):
            try part(inner, at: place)

        case let .dictionary(key, value):
            try part(key, at: place)
            try part(value, at: place)
            try keyed(by: key, at: place, bounds: bounds, sameTypes: sameTypes, in: table)

        case let .nullable(inner):
            try part(inner, at: place)
            try questioned(inner, at: place, in: table)
        }
    }

    // An associated type is one a contract bounding what it stands on asks.
    private func asked(_ name: Name, of owner: Name, at place: Place, bounds: [Name: Set<Name>], in table: TypeTable) throws {
        let contracts = table.loweredTypes.contracts(bounding: owner, under: bounds)

        guard table.loweredTypes.bounds(of: name, askedBy: contracts) != nil else {
            let bounding = contracts.sorted().map(\.spelling).joined(separator: " & ")

            throw BuildError(
                "writes `\(TypeExpression.associatedType(of: owner, name: name).rendered)`, and "
                    + (bounding.isEmpty ? "no contract bounds '\(owner)'" : "'\(owner)' is bounded by \(bounding)")
                    + ", which asks no type '\(name)'. An associated type is one a contract bounding what it stands on asks",
                at: place
            )
        }
    }

    // A value of whatever type answers every name: each has to be a
    // contract's, since a type is one thing and not a bound on some other.
    private func joined(_ names: Set<Name>, at place: Place, in table: TypeTable) throws {
        for name in names.sorted() where table.contracts[name] == nil {
            throw BuildError(
                "joins '\(name)' with `&`, and `&` joins the names of contracts,"
                    + " which no module in this link declares '\(name)' as",
                at: place
            )
        }
    }

    private func declared(_ name: Name, at place: Place, in table: TypeTable) throws {
        guard table.types[name] != nil || table.contracts[name] != nil else {
            throw BuildError(
                "names type '\(name)', which no module in this"
                    + " link declares",
                at: place
            )
        }
    }

    // The load held a `?` to saying something new on what it wraps as
    // written. A name may stand for what it says nothing on, and that is
    // known here, where names resolve: what the name lowers to, spelled.
    private func questioned(_ inner: TypeExpression, at place: Place, in table: TypeTable) throws {
        guard case .named = inner else { return }

        let stands = inner.lowered(in: table.loweredTypes).spelled(in: table.loweredTypes)

        guard stands.takesQuestionMark else {
            throw BuildError(
                "writes `?` on \(inner.rendered), which"
                    + " stands for `\(stands.rendered)`. A `?` says"
                    + " nothing there, the same rule the spelling"
                    + " `\(stands.rendered)?` is refused by",
                at: place
            )
        }
    }

    // The types a declared type names: each field's, or what an alias
    // stands for.
    private func mentioned(
        in declared: TypeDeclaration,
        at place: Place,
        resolve table: TypeTable
    ) throws {
        switch declared {
        case let .struct(fields, typeParameters, bounds):
            for (name, field) in fields.sorted(by: { one, other in one.key < other.key }) {
                try mentioned(
                    in: field,
                    at: place.part(.fields).key(name.spelling),
                    bounds: bounds,
                    resolve: table
                )
            }

            try judge(
                bounds: bounds,
                at: { parameter in
                    typeParameters.firstIndex(of: parameter).map { position in place.part(.typeParameters).index(position) }
                        ?? place.part(.typeParameters)
                },
                in: table
            )

        case let .alias(type):
            try mentioned(in: type, at: place, resolve: table)
        }
    }

    // A declared name applied to as many types as its declaration takes:
    // a struct to one per type parameter it lists, each answering the
    // bounds of its position the way a map's key answers `Hashable`, and
    // an alias or a contract to none.
    private func applied(
        _ name: Name,
        to arguments: [TypeExpression],
        at place: Place,
        bounds: [Name: Set<Name>],
        sameTypes: [Name: TypeExpression],
        in table: TypeTable
    ) throws {
        guard case let .struct(_, typeParameters, declaredBounds) = table.types[name] else {
            guard arguments.isEmpty else {
                throw BuildError(
                    "applies '\(name)' to \(arguments.count) type(s), and '\(name)' is no struct"
                        + " taking type parameters. Only a struct lists them",
                    at: place
                )
            }

            return
        }

        guard arguments.count == typeParameters.count else {
            let taking = typeParameters.map { parameter in "'\(parameter)'" }.joined(separator: ", ")

            throw BuildError(
                "applies '\(name)' to \(arguments.count) type(s), and '\(name)' takes"
                    + (typeParameters.isEmpty ? " none" : " \(typeParameters.count), its type parameters \(taking)"),
                at: place
            )
        }

        let types = table.loweredTypes

        for (parameter, argument) in zip(typeParameters, arguments) {
            for contract in declaredBounds[parameter, default: []].sorted() {
                if let refusal = types.refusal(
                    of: argument.lowered(in: types, bounds: bounds, sameTypes: sameTypes),
                    answering: contract,
                    orNull: false,
                    as: "applies '\(name)' at '\(parameter)' to"
                ) {
                    throw BuildError(refusal, at: place)
                }
            }
        }
    }

    // A map's key answers `Hashable`, by the claims the table holds.
    private func keyed(
        by key: TypeExpression,
        at place: Place,
        bounds: [Name: Set<Name>],
        sameTypes: [Name: TypeExpression],
        in table: TypeTable
    ) throws {
        let types = table.loweredTypes

        if let refusal = types.keyRefusal(
            of: key.lowered(in: types, bounds: bounds, sameTypes: sameTypes)
        ) {
            throw BuildError(refusal, at: place)
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
    // name a bound names has to be a contract somebody declared. `place`
    // says where each parameter's bounds are written.
    private func judge(
        bounds: [Name: Set<Name>],
        at place: (Name) -> Place,
        in table: TypeTable
    ) throws {
        for (parameter, names) in bounds.sorted(by: { $0.key < $1.key }) {
            for bound in names.sorted() where table.contracts[bound] == nil {
                throw BuildError(
                    "bounds '\(parameter)' by '\(bound)', which no module in this link declares as a contract",
                    at: place(parameter)
                )
            }
        }
    }
}
