//
//  Linker+Judging.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What the link refuses about a declaration on its own: a type mention that
// resolves to nothing, a parameter no call could fit, a constraint no value
// satisfies, and a call site whose arguments do not answer what the callee
// asked. The walk through a body is `Linker+Typing`.
extension Linker {
    // MARK: - Internal
    // The one gate every gathered call passes, wherever its body sits. A
    // procedure, a word, a constant's closure. The call carries the declaration
    // the walk found for it, and is judged against that.
    func checked(_ calls: [CallSite], in frame: TypeFrame) throws {
        for call in calls {
            try check(call, against: call.callee.procedure, with: frame)
        }
    }

    // Every type a body mentions, held where it is written: the signatures its
    // closures carry, the shapes its casts name, and what its names say they
    // hold. Three name spaces bury a body (a procedure's, a constant's and a
    // variable's) and one of them was once missing a judgment the other two
    // made, so the three ask this rather than each holding a copy.
    //
    // Asking it where types are inferred instead would ask only of what that
    // walk reaches: a procedure both impure and unreachable is walked by
    // neither the frontier nor the pure set, and its mentions would name
    // whatever they liked.
    func judge(buried held: some Burying, at place: Place, in table: TypeTable) throws {
        let buried = held.buried(at: place)

        for (place, inner) in closures(in: buried) {
            try judge(inner.signature, at: place, in: table)
        }

        for (place, named) in castTypes(in: buried) {
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
    // mentions resolves, every parameter could be filled, every constraint it
    // names is declared and single, and the receiver it names is a parameter it
    // declares. The facts every consumer of the signature reads instead of
    // re-deriving.
    func judge(
        _ signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        for (input, parameter) in signature.parameters.sorted { $0.key < $1.key } {
            try mentioned(
                in: parameter.declared.inoutUnwrapped,
                at: place.slot(.parameters).key(input.spelling),
                parameterized: true,
                resolve: table
            )
            try judge(parameter, called: input, at: place.slot(.parameters).key(input.spelling), in: table)
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

    // Everything a cast's shape is held to on its spelling alone: the names it
    // mentions resolve, and it names a shape there is something to read. Both
    // are answered without knowing what the value reads as, so both belong to
    // the pass that sees every cast rather than to the walk that sees the
    // reached ones. A procedure both impure and unreachable is walked by
    // neither the frontier nor the pure set.
    func judge(
        cast named: TypeExpression,
        at place: Place,
        in table: TypeTable
    ) throws {
        try mentioned(in: named, at: place, parameterized: true, resolve: table)

        if let refusal = named.resolved(in: table).unreadableClaim {
            throw LinkError(refusal, at: place)
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
    // here rather than at the sites that name it. Internal, because a cast asks
    // it too: a type spelling in a body is a mention like any other, and a
    // second copy of "this name is declared" living in the typing walk is
    // exactly the drift the rule exists against.
    func mentioned(
        in type: TypeExpression,
        at place: Place,
        parameterized: Bool,
        declaring: Bool = false,
        nested: Bool = false,
        resolve table: TypeTable
    ) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes:
            return

        // The link's own note to itself, written where a declaration goes. A
        // declaration is a promise, and this is a shape worked out from a body.
        // Nobody promised it, and no document could have spelled it. It is
        // refused here rather than left to the reader, because a reader is one
        // way a declaration is built and a host assembling one is another.
        case let .reading(of, path):
            throw LinkError(
                "writes `\(type.rendered)`, which is a shape the link"
                    + " read out of a body. A declaration says what a call fills,"
                    + " and `\(([PathSegment.key(of)] + path).rendered)` is a path"
                    + " only that body can read",
                at: place
            )

        // The bounds are the declaration's own claim, so an order the numbers
        // refuse is refused where it was written. A range below its own floor
        // is a slot no call could ever fit, the way an empty `oneOf` is.
        case let .ranged(refinement):
            if refinement.saysNothing {
                throw LinkError(
                    "writes `\(type.rendered)` with neither bound."
                        + " A range that says nothing is spelled"
                        + " `\(refinement.kind.rendered)`",
                    at: place
                )
            }

            if refinement.admitsNothing {
                throw LinkError(
                    "writes `\(type.rendered)`, which admits nothing."
                        + " No \(refinement.kind.rendered) is inside it",
                    at: place
                )
            }

            return

        case .parameter:
            guard parameterized else {
                throw LinkError(
                    "writes `\(type.rendered)`, and nothing here is"
                        + " filled by a call. A type parameter lives in a signature",
                    at: place
                )
            }

        // The flag rides through rather than turning on: a procedure type in a
        // signature's slot is part of that signature, and one in a declared
        // type is not a filling site. A parameter written there is never bound
        // at any call, so the bound it claims would be a claim nothing judges.
        case let .procedure(signature, _, _):
            guard let signature else { return }

            for (name, parameter) in signature.parameters.sorted { $0.key < $1.key } {
                try mentioned(
                    in: parameter.declared.inoutUnwrapped,
                    at: place.key(name.spelling),
                    parameterized: parameterized,
                    nested: nested,
                    resolve: table
                )
                try judge(parameter, called: name, at: place.key(name.spelling), in: table)
            }

            try mentioned(
                in: signature.returns ?? .any,
                at: place,
                parameterized: parameterized,
                resolve: table
            )

            try judgeConstraints(of: signature, at: place, in: table)

        // Types and memberships are two spaces and no name is in both, so a
        // mention reaches whichever declares it. A membership standing here is
        // a value of one of its members.
        case let .named(name):
            guard table.resolve(name) != nil || table.constraint(name) != nil else {
                throw LinkError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

            // A value handed on once is followed by the name that holds it, so
            // it stands where a name can hold it and nowhere else. Inside
            // another shape there is no name to follow, and what the shape
            // does with what it carries is not something the link can read.
            guard !nested || !handedOnce(.named(name), in: table) else {
                throw LinkError(
                    "carries '\(name)' inside another shape, and a value written"
                        + " `once` is followed by the name that holds it."
                        + " Nothing follows one inside a list, a record or"
                        + " another declaration",
                    at: place
                )
            }

        case let .array(element), let .dictionary(element):
            try mentioned(in: element, at: place, parameterized: parameterized, nested: true, resolve: table)

        // The reader refuses a `?` that says nothing new, but the reader sees
        // spellings, and a name may hide one of the refused shapes behind it.
        // The rule is the model's, so it is held here too, where names resolve:
        // whatever surface wrote the type, `?` wraps only what does not already
        // answer the null question.
        case let .nullable(inner):
            var resolved = inner

            while case let .named(next) = resolved, let underneath = table.resolve(next) {
                resolved = underneath
            }

            switch resolved {
            case .any, .null, .never, .parameter, .nullable:
                throw LinkError(
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
                    at: place.key(name.spelling),
                    parameterized: parameterized,
                    nested: true,
                    resolve: table
                )
            }

        case .inout:
            throw LinkError(
                "writes `\(type.rendered)`, and only a parameter is handed a"
                    + " variable in place. `inout` is written on a parameter's type",
                at: place
            )

        case .variable:
            throw LinkError(
                "writes `\(type.rendered)`, and only a field of a declared type"
                    + " is written through. `var` is written on a field in `types`",
                at: place
            )

        // Only a declared type is handed on once. The obligation rides with
        // the name, so a slot mentioning the name has it and a slot writing
        // the word would be claiming it for a shape nothing declared it of.
        case let .once(inner):
            guard declaring else {
                throw LinkError(
                    "writes `\(type.rendered)`, and only a declared type is"
                        + " handed on once. `once` is written on a type in `types`,"
                        + " and a slot naming that type carries it",
                    at: place
                )
            }

            try mentioned(in: inner, at: place, parameterized: parameterized, resolve: table)
        }
    }

    // Whether a parameter's own declaration can be satisfied at all. Facts it
    // states about itself, judged wherever a parameter is written: a `oneOf`
    // none of whose candidates the declared type admits is a parameter no call
    // could ever fit, and a default the parameter itself would refuse is a
    // refusal waiting for the one call that leans on it.
    func judge(
        _ parameter: Parameter,
        called name: Name,
        at place: Place,
        in table: TypeTable
    ) throws {
        // The declaration as the boundary reads it, so what the link calls
        // dead is exactly what the boundary would never match.
        let shape = parameter.declared.lowered(in: table.shapes)

        if let allowed = parameter.oneOf {
            // Candidate by candidate: a spelling the declared type cannot spell
            // is a member no call could ever match, and a dead member is the
            // declaration's own defect whether live ones stand beside it or
            // not. One pass reads both facts. A list that is empty or entirely
            // dead refuses by the plainer name, a dead member among live ones
            // is named.
            let dead = allowed.filter { candidate in
                !shape.spells(candidate, in: table.shapes)
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
                        + " \(parameter.declared.rendered) does not admit."
                        + " No call could ever match it",
                    at: place
                )
            }
        }

        guard let fallback = parameter.default else { return }

        // An explicitly-null default is the value the body receives when the
        // argument is left out, so the declaration must admit null like any
        // other value, and a `oneOf` never lists it, since null has no scalar
        // spelling. Asked of the value judge itself, since the slot reads an
        // explicit null default as its own legacy spelling of `T?`.
        if fallback == .null {
            guard parameter.oneOf == nil, shape.settles(.null, in: table.shapes) else {
                throw LinkError(
                    "its default is not a value it takes: null",
                    at: place
                )
            }

            return
        }

        do {
            _ = try parameter.checking(fallback, called: name, in: table)
        } catch {
            throw LinkError(
                "its default is not a value it takes: \(error)",
                at: place
            )
        }
    }

    // MARK: - Private
    // Every shape a cast names in here, however deep, each with where it was
    // found. What the walk buries is `buried`'s to know. This says only which
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
    // takes one constraint. Each occurrence carries its bound separately, so
    // occurrences carrying different bounds for one name are two claims about
    // one thing.
    private func judgeConstraints(
        of signature: Signature,
        at place: Place,
        in table: TypeTable
    ) throws {
        var bounds: [Name: Set<Name>] = [:]
        signature.parameterConstraints(into: &bounds)

        for (parameter, names) in bounds.sorted { $0.key < $1.key } {
            guard names.count <= 1 else {
                throw LinkError(
                    "`some \(parameter)` is bounded by"
                        + " \(names.sorted().map(\.spelling).joined(separator: " and "))."
                        + " One parameter takes one constraint",
                    at: place
                )
            }

            // A bound names a membership or a contract. The two are separate
            // spaces and no name is in both, so a mention reaches whichever
            // declares it.
            guard
                let bound = names.first,
                table.constraint(bound) == nil,
                table.contracts[bound] == nil
            else {
                continue
            }

            throw LinkError(
                "`some \(parameter)` names '\(bound)', which no module in this"
                    + " link declares as a membership or a contract",
                at: place
            )
        }
    }

    private func check(
        _ site: CallSite,
        against callee: Procedure,
        with frame: TypeFrame
    ) throws {
        let call = site.call
        let shapes = frame.shapes

        // One parameter takes one argument. A receiver written in front of
        // the dot and again by name is refused before either is read, since
        // the one by name would be neither read nor run.
        if let receiver = callee.signature.receiver, call.receiver != nil, call.arguments[receiver] != nil {
            throw LinkError(
                "sending '\(call.selector)' with '\(receiver)' both in front and by name",
                at: site.place.slot(.arguments)
            )
        }

        // A declaration with a type parameter in it is checked with the
        // parameter filled, or a slot standing for whatever arrives would
        // refuse whatever arrived. The judgment (a parameter read two ways has
        // no answer, a bounded one takes only what its constraint admits) is
        // the one every call surface shares, so this only gathers what the call
        // wrote into each slot. This is what one signature says in place of the
        // several a language with overloading would need: `some N` on both
        // sides and on the way out is a whole number and a whole number
        // answering a whole number, and a whole number and a fraction refused,
        // without a way to declare a name twice.
        let declared = callee.signature

        let signature: Signature

        switch judged(
            declared,
            filledWith: bound(
                of: declared,
                at: call,
                readings: site.readings,
                receiver: site.received,
                in: shapes
            ),
            in: shapes
        ) {
        case let .refusal(reason):
            throw LinkError(
                "sending '\(call.selector)': \(reason)",
                at: site.place
            )

        case let .fits(filled):
            signature = filled
        }
        let undeclared = call.arguments.keys
            .filter { name in signature.parameters[name] == nil }
            .sorted()

        guard undeclared.isEmpty else {
            throw LinkError(
                "sending '\(call.selector)' with"
                    + " \(undeclared.map(\.spelling).joined(separator: ", ")), which it does not declare",
                at: site.place.slot(.arguments)
            )
        }

        // A receiver is written on the other side of the dot rather than by
        // name, so a site that sends one has supplied that parameter.
        let supplied = Set(call.arguments.keys)
            .union(call.receiver == nil ? [] : [signature.receiver].compactMap { $0 })

        let missing = signature.parameters
            .filter { name, parameter in
                parameter.mustBeGiven(in: shapes) && !supplied.contains(name)
            }
            .keys
            .sorted()

        guard missing.isEmpty else {
            throw LinkError(
                "sending '\(call.selector)' without"
                    + " \(missing.map(\.spelling).joined(separator: ", ")), which it requires",
                at: site.place.slot(.arguments)
            )
        }

        // An argument that needs a scope cannot be judged here. Only the ones
        // that already are what they will be. `taking` rather than `checking`,
        // so a constant passes exactly the gate the run would apply to it.
        for (name, argument) in call.arguments.sorted(by: { left, right in left.key < right.key }) {
            guard
                let parameter = signature.parameters[name],
                let constant = argument.constantValue
            else {
                continue
            }

            do {
                _ = try parameter.lowered(named: name, in: shapes).taking(constant, in: shapes)
            } catch {
                throw LinkError(
                    "sending '\(call.selector)': \(error)",
                    at: site.place.argument(name.spelling)
                )
            }
        }

        // A word may judge its own constant arguments before any run. A type
        // cannot say that a regex pattern compiles, and the word can. It
        // happens here rather than while decoding, because a notation judging
        // arguments would have to know the vocabulary; judging belongs where
        // names resolve.
        if case let .query(query) = callee.implementation {
            let constants = call.arguments.compactMapValues(\.constantValue)

            do {
                try query.validate(constants)
            } catch {
                throw LinkError(
                    "sending '\(call.selector)': \(error)",
                    at: site.place.slot(.arguments)
                )
            }
        }

        // What an argument holds is read from the body it was written in, so a
        // name bound to a call carries that call's declared answer. This is what
        // makes declaring an answer worth anything before a run: both sides are
        // declarations, and a declaration is text. The site carries the walk's
        // readings, so nothing is walked again for the asking.
        for name in call.arguments.keys.sorted() {
            guard let parameter = signature.parameters[name] else { continue }

            let written = site.readings[name] ?? .any

            guard !parameter.declared.accepts(written, in: shapes) else { continue }

            throw LinkError(
                "sending '\(call.selector)' with \(name),"
                    + " which holds \(written) where \(parameter.declared) is declared",
                at: site.place.argument(name.spelling)
            )
        }

        // The receiver is written on the other side of the dot and checked the
        // same way.
        if
            let written = site.received,
            let name = signature.receiver,
            let parameter = signature.parameters[name]
        {
            guard parameter.declared.accepts(written, in: shapes) else {
                throw LinkError(
                    "sending '\(call.selector)' to \(written),"
                        + " where \(parameter.declared) is declared",
                    at: site.place.slot(.receiver)
                )
            }
        }
    }
}
