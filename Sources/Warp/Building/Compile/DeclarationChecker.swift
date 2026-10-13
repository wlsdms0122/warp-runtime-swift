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
        // take a run of table rows, in the order the documents stand.
        let table = TypeTable(
            types: declared.mapValues(\.held),
            contracts: namespace.contracts.mapValues(\.held),
            standing: Prelude.types.keys.sorted() + documents.flatMap { document in document.types.keys.sorted() },
            of: linkage
        )

        // The table is walked whole rather than per module: it arrives
        // carrying where each name was written, and asking a module again
        // would be spelling that a second way.
        for (_, declaration) in declared.sorted(by: { $0.key < $1.key }) {
            try mentioned(in: declaration.held, at: declaration.place, resolve: table)
        }

        return table
    }

    // Every type a document names, held to being one the link declares, and
    // every map type it names keyed by a type that answers `Hashable`. A
    // document is read on its own: what is judged is its own text, and the
    // table is what the whole link declared. Where the table cannot say
    // whether a key answers, the pair is written down for the document at
    // its place in the link, from `origin` on.
    func judge(_ modules: [Module], from origin: Int = 0, in table: TypeTable) throws {
        for (offset, module) in modules.enumerated() {
            table.loweredTypes.fulfillment?.laying(origin + offset, at: Place(in: .of(module)))

            for (name, declared) in module.types.sorted(by: { $0.key < $1.key }) {
                try mentioned(in: declared, at: .type(name.spelling, in: .of(module)), resolve: table)
            }

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
                if case let .body(block) = procedure.implementation {
                    try judge(
                        subexpressions: block,
                        at: .procedure(name.spelling, in: .of(module)),
                        bounds: procedure.signature.bounds,
                        in: table
                    )
                }
            }

            try judge(contracts: module.contracts, of: .of(module), in: table)
            try judge(heads: Set(module.claims.keys).union(module.members.keys), of: .of(module), in: table)

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

    // Every type an object's signatures name, held to being one the link
    // declares, the way a document's are where it is compiled: an object
    // compiled against other documents may name what none of these declares.
    // What its declared types name is held by `types`, and what its bodies
    // stand on where their numbers are answered with rows.
    func judge(_ objects: [Compiled], in table: TypeTable) throws {
        for object in objects {
            for row in object.table {
                try judge(row.signature, at: .procedure(row.label.spelling, in: object.document), in: table)
            }

            try judge(contracts: object.contracts, of: object.document, in: table)
            try judge(heads: Set(object.claims.keys).union(object.members.keys), of: object.document, in: table)
        }
    }

    // MARK: - Private
    // A contract's procedures are declarations the way a document's own are,
    // and what a call is judged against is what was judged. `Self` is read
    // as one type parameter the contract bounds.
    private func judge(
        contracts: [Name: [Name: ContractProcedure]],
        of document: Place.Document,
        in table: TypeTable
    ) throws {
        for (contract, procedures) in contracts.sorted(by: { $0.key < $1.key }) {
            for (name, asked) in procedures.sorted(by: { $0.key < $1.key }) {
                let place = Place.contract(contract.spelling, in: document).key(name.spelling)

                try judge(asked.signature.read(of: contract), at: place, in: table)
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

            for (parameter, names) in head.bounds.sorted(by: { $0.key < $1.key }) {
                for bound in names.sorted() where table.contracts[bound] == nil {
                    throw BuildError(
                        "`\(TypeExpression.parameter(name: parameter).rendered)` names '\(bound)',"
                            + " which no module in this link declares as a contract",
                        at: place
                    )
                }
            }
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
        in table: TypeTable
    ) throws {
        let subexpressions = held.subexpressions(at: place)

        for (place, inner) in closures(in: subexpressions) {
            try judge(inner.signature.bounded(by: bounds), at: place, in: table)
        }

        for (place, named) in castTypes(in: subexpressions) {
            try judge(cast: named, at: place, bounds: bounds, in: table)
        }

        // A name saying what it holds is a mention like the other two.
        for (place, declared) in held.declaring(at: place) {
            try mentioned(in: declared, at: place, bounds: bounds, resolve: table)
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
                resolve: table
            )
        }

        try mentioned(in: signature.returns ?? .any, at: place.part(.returns), bounds: signature.bounds, resolve: table)

        try judge(bounds: signature.bounds, at: place, in: table)
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
        in table: TypeTable
    ) throws {
        try mentioned(in: named, at: place, bounds: bounds, resolve: table)

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
        resolve table: TypeTable
    ) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .string, .selfType, .parameter, .projection:
            return

        case let .procedure(type, _, _):
            guard let type else { return }

            for (position, parameter) in type.parameters.enumerated() {
                try mentioned(in: parameter.slotUnwrapped, at: place.index(position), bounds: bounds, resolve: table)
            }

            try mentioned(in: type.returns ?? .any, at: place.part(.returns), bounds: bounds, resolve: table)

        // A value of whatever type answers every name: each has to be a
        // contract's, since a type is one thing and not a bound on some
        // other.
        case let .composition(names):
            for name in names.sorted() where table.contracts[name] == nil {
                throw BuildError(
                    "joins '\(name)' with `&`, and `&` joins the names of contracts,"
                        + " which no module in this link declares '\(name)' as",
                    at: place
                )
            }

        // Types and contracts are two tables and no name is in both, so a
        // mention reaches whichever declares it. A contract standing here is
        // a value of whatever type answers it.
        case let .named(name, arguments):
            guard table.types[name] != nil || table.contracts[name] != nil else {
                throw BuildError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

            for argument in arguments {
                try mentioned(in: argument, at: place, bounds: bounds, resolve: table)
            }

            try applied(name, to: arguments, at: place, bounds: bounds, in: table)

        case let .array(inner), let .inout(inner), let .variable(inner):
            try mentioned(in: inner, at: place, bounds: bounds, resolve: table)

        case let .dictionary(key, value):
            try mentioned(in: key, at: place, bounds: bounds, resolve: table)
            try mentioned(in: value, at: place, bounds: bounds, resolve: table)
            try keyed(by: key, at: place, bounds: bounds, in: table)

        // The load held a `?` to saying something new on what it wraps as
        // written. A name may stand for what it says nothing on, and that is
        // known here, where names resolve: what the name lowers to, spelled.
        case let .nullable(inner):
            try mentioned(in: inner, at: place, bounds: bounds, resolve: table)

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
    }

    // The types a declared type names: each field's, or what an alias
    // stands for.
    private func mentioned(
        in declared: TypeDeclaration,
        at place: Place,
        resolve table: TypeTable
    ) throws {
        switch declared {
        case let .struct(fields, _, bounds):
            for (name, field) in fields.sorted(by: { one, other in one.key < other.key }) {
                try mentioned(in: field, at: place.part(.fields).key(name.spelling), bounds: bounds, resolve: table)
            }

            try judge(bounds: bounds, at: place, in: table)

        case let .alias(type):
            try mentioned(in: type, at: place, resolve: table)
        }
    }

    // A declared name applied to as many types as its declaration takes:
    // a struct to one per type parameter it lists, each answering the
    // bounds of its position the way a map's key answers `Hashable`, and
    // an alias or a contract to none. Where the table cannot say whether
    // one answers, the pair is written down where the mention stands.
    private func applied(
        _ name: Name,
        to arguments: [TypeExpression],
        at place: Place,
        bounds: [Name: Set<Name>],
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
                    of: argument.lowered(in: types, bounds: bounds),
                    answering: contract,
                    orNull: false,
                    as: "applies '\(name)' at '\(parameter)' to",
                    leaning: { leaning in types.fulfillment?.require(leaning, at: place) }
                ) {
                    throw BuildError(refusal, at: place)
                }
            }
        }
    }

    // A map's key answers `Hashable`. Where the table cannot say, the pair
    // is written down where the map is mentioned, for the link that holds
    // every claim.
    private func keyed(
        by key: TypeExpression,
        at place: Place,
        bounds: [Name: Set<Name>],
        in table: TypeTable
    ) throws {
        let types = table.loweredTypes

        if let refusal = types.keyRefusal(
            of: key.lowered(in: types, bounds: bounds),
            leaning: { leaning in types.fulfillment?.require(leaning, at: place) }
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
    // name a bound names has to be a contract somebody declared.
    private func judge(
        bounds: [Name: Set<Name>],
        at place: Place,
        in table: TypeTable
    ) throws {
        for (parameter, names) in bounds.sorted(by: { $0.key < $1.key }) {
            for bound in names.sorted() where table.contracts[bound] == nil {
                throw BuildError(
                    "`\(TypeExpression.parameter(name: parameter).rendered)` names '\(bound)',"
                        + " which no module in this link declares as a contract",
                    at: place.part(.bounds).key(parameter.spelling)
                )
            }
        }
    }
}
