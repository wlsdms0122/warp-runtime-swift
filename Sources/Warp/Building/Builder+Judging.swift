//
//  Builder+Judging.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What the link refuses about a declaration on its own: a type mention that
// resolves to nothing, a parameter no call could fit, a constraint no value
// satisfies, and a call site whose arguments do not answer what the callee
// asked. The walk through a body is `Builder+Typing`.
extension Builder {
    // MARK: - Internal
    // The one gate every gathered call passes, wherever its body sits. A
    // native procedure, a written body, a constant's closure. The call carries the
    // the walk found for it, and is judged against that.
    func checked(_ calls: [CallSite], in context: TypingContext, writing fulfillment: Fulfillment) throws {
        for call in calls {
            guard let callee = context.declared(call.callee) else {
                throw BuildError.unjudged(
                    "a call to '\(call.callee)', which has no row",
                    at: call.place
                )
            }

            try check(call, against: callee, with: context, writing: fulfillment)
        }
    }

    // Every type a body mentions, held where it is written: the signatures its
    // closures carry, the types its casts name, and what its names say they
    // hold. Three name spaces bury a body (a procedure's, a constant's and a
    // variable's) and one of them was once missing a judgment the other two
    // made, so the three ask this rather than each holding a copy.
    //
    // Asking it where types are inferred instead would ask only of what that
    // walk reaches: a procedure both impure and unreachable is walked by
    // neither the frontier nor the pure set, and its mentions would name
    // whatever they liked.
    func judge(subexpressions held: some Traversable, at place: Place, in table: TypeTable) throws {
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
                in: parameter.declared.slotUnwrapped,
                at: place.part(.parameters).key(input.spelling),
                parameterized: true,
                resolve: table
            )
            try saysWhatItDoes(
                with: parameter.declared,
                at: place.part(.parameters).key(input.spelling),
                in: table
            )
            try judge(parameter, called: input, at: place.part(.parameters).key(input.spelling), in: table)
        }

        try mentioned(
            in: signature.returns ?? .any,
            at: place.part(.returns),
            parameterized: true,
            resolve: table
        )

        try judgeConstraints(of: signature, at: place, in: table)

        if let receiver = signature.receiver, signature.parameters[receiver] == nil {
            throw BuildError(
                "receiver names '\(receiver)', which this"
                    + " signature does not declare",
                at: place
            )
        }
    }

    // Everything a cast's type is held to on its spelling alone: the names it
    // mentions resolve, and it names a type there is something to read. Both
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
            throw BuildError(refusal, at: place)
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
        // declaration is a promise, and this is a type worked out from a body.
        // Nobody promised it, and no document could have spelled it. It is
        // refused here rather than left to the reader, because a reader is one
        // way a declaration is built and a host assembling one is another.
        case let .reading(of, path):
            throw BuildError(
                "writes `\(type.rendered)`, which is a type the build"
                    + " read out of a body. A declaration says what a call fills,"
                    + " and `\(([PathSegment.key(of)] + path).rendered)` is a path"
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
        case let .procedure(signature, _, _):
            guard let signature else { return }

            for (name, parameter) in signature.parameters.sorted { $0.key < $1.key } {
                try mentioned(
                    in: parameter.declared.slotUnwrapped,
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

        // Types and memberships are two tables and no name is in both, so a
        // mention reaches whichever declares it. A membership standing here is
        // a value of one of its members.
        case let .named(name):
            guard table.resolve(name) != nil || table.constraint(name) != nil else {
                throw BuildError(
                    "names type '\(name)', which no module in this"
                        + " link declares",
                    at: place
                )
            }

            // A value handed on once is followed by the name that holds it, so
            // it stands where a name can hold it and nowhere else. Inside
            // another type there is no name to follow, and what the type
            // does with what it carries is not something the link can read.
            guard !nested || !Builder.handedOnce(.named(name), in: table) else {
                throw BuildError(
                    "carries '\(name)' inside another type, and a value written"
                        + " `linear` is followed by the name that holds it."
                        + " Nothing follows one inside a list, a record or"
                        + " another declaration",
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

            while case let .named(next) = resolved, let underneath = table.resolve(next) {
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
            guard !Builder.handedOnce(inner, in: table) else {
                throw BuildError(
                    "writes `?` on \(inner.rendered), \(Builder.doubtOverAnObligation)",
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
                    at: place.key(name.spelling),
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
            guard !Builder.handedOnce(declared.slotUnwrapped, in: table) else { return }

            throw BuildError(
                "takes '\(declared.rendered)', and a slot says what it does with a"
                    + " value handed on once by naming the type that is one. No"
                    + " value of the type written here is",
                at: place
            )

        default:
            guard Builder.handedOnce(declared.slotUnwrapped, in: table) else { return }

            throw BuildError(
                "takes '\(declared.rendered)', which is handed on once, and says"
                    + " nothing about what it does with it. A parameter taking one"
                    + " writes `consuming` where the obligation moves to it, and"
                    + " `borrowing` where the obligation stays with the caller",
                at: place
            )
        }
    }

    // Whether a parameter's own declaration can be satisfied at all. Facts it
    // states about itself, judged wherever a parameter is written: a `enum`
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

        guard let fallback = parameter.default else { return }

        // An explicitly-null default is the value the body receives when the
        // argument is left out, so the declaration must admit null like any
        // other value, and a `enum` never lists it, since null has no scalar
        // spelling. Asked of the value judge itself, since the slot reads an
        // explicit null default as its own legacy spelling of `T?`.
        if fallback == .null {
            guard parameter.candidates == nil, type.settles(.null, in: table.loweredTypes) else {
                throw BuildError(
                    "its default is not a value it takes: null",
                    at: place
                )
            }

            return
        }

        do {
            _ = try parameter.checking(fallback, called: name, in: table)
        } catch {
            throw BuildError(
                "its default is not a value it takes: \(error)",
                at: place
            )
        }
    }

    // MARK: - Private
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
                throw BuildError(
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

            throw BuildError(
                "`some \(parameter)` names '\(bound)', which no module in this"
                    + " link declares as a membership or a contract",
                at: place
            )
        }
    }

    private func check(
        _ site: CallSite,
        against callee: Linked,
        with context: TypingContext,
        writing fulfillment: Fulfillment
    ) throws {
        let call = site.call
        let loweredTypes = context.loweredTypes

        // One parameter takes one argument. A receiver written in front of
        // the dot and again by name is refused before either is read, since
        // the one by name would be neither read nor run.
        if let receiver = callee.signature.receiver, call.receiver != nil, call.arguments[receiver] != nil {
            throw BuildError(
                "sending '\(call.selector)' with '\(receiver)' both in front and by name",
                at: site.place.part(.arguments)
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

        let declaredSlots = context.slots(of: call.selector)

        let slots: [Slot]

        switch judged(
            declared,
            over: declaredSlots,
            answering: context.answer(of: call.selector),
            filledWith: bound(
                of: declared,
                over: declaredSlots,
                at: call,
                readings: site.readings,
                receiver: site.received,
                in: loweredTypes
            ),
            in: loweredTypes,
            fulfillment: fulfillment,
            at: site.place
        ) {
        case let .refusal(reason):
            throw BuildError(
                "sending '\(call.selector)': \(reason)",
                at: site.place
            )

        case let .fits(filled, _):
            slots = filled
        }

        // Found by name along the list, the way the boundary finds one: a
        // declaration's slots are few and in name order.
        func slot(_ name: Name) -> Slot? {
            slots.first { slot in slot.name == name }
        }

        let undeclared = call.arguments.keys
            .filter { name in slot(name) == nil }
            .sorted()

        guard undeclared.isEmpty else {
            throw BuildError(
                "sending '\(call.selector)' with"
                    + " \(undeclared.map(\.spelling).joined(separator: ", ")), which it does not declare",
                at: site.place.part(.arguments)
            )
        }

        // A receiver is written on the other side of the dot rather than by
        // name, so a site that sends one has supplied that parameter.
        let supplied = Set(call.arguments.keys)
            .union(call.receiver == nil ? [] : [declared.receiver].compactMap { $0 })

        let missing = slots
            .filter { slot in slot.mustBeGiven(in: loweredTypes) && !supplied.contains(slot.name) }
            .map(\.name)
            .sorted()

        guard missing.isEmpty else {
            throw BuildError(
                "sending '\(call.selector)' without"
                    + " \(missing.map(\.spelling).joined(separator: ", ")), which it requires",
                at: site.place.part(.arguments)
            )
        }

        // An argument that needs a scope cannot be judged here. Only the ones
        // that already are what they will be. `taking` rather than `checking`,
        // so a constant passes exactly the gate the run would apply to it.
        for (name, argument) in call.arguments.sorted(by: { left, right in left.key < right.key }) {
            guard let slot = slot(name), let constant = argument.constantValue else { continue }

            do {
                _ = try slot.taking(constant, in: loweredTypes)
            } catch {
                throw BuildError(
                    "sending '\(call.selector)': \(error)",
                    at: site.place.argument(name.spelling)
                )
            }
        }

        // A procedure may judge its own constant arguments before any run. A type
        // cannot say that a regex pattern compiles, and the procedure can. It
        // happens here rather than while decoding, because a notation judging
        // arguments would have to know the vocabulary; judging belongs where
        // names resolve.
        // A procedure's own keys name its parameters, so what a call wrote by name
        // is asked for by key here, through the same door the procedure reads an
        // argument through when it answers.
        func validate(_ query: some Query, given constants: [Name: Value]) throws {
            try query.validate(Question(arguments: constants))
        }

        if case let .native(.query(query)) = callee.implementation {
            let constants = call.arguments.compactMapValues(\.constantValue)

            do {
                try validate(query, given: constants)
            } catch {
                throw BuildError(
                    "sending '\(call.selector)': \(error)",
                    at: site.place.part(.arguments)
                )
            }
        }

        // What an argument holds is read from the body it was written in, so a
        // name bound to a call carries that call's declared answer. This is what
        // makes declaring an answer worth anything before a run: both sides are
        // declarations, and a declaration is text. The site carries the walk's
        // readings, so nothing is walked again for the asking.
        for name in call.arguments.keys.sorted() {
            guard let slot = slot(name) else { continue }

            let written = site.readings[name] ?? .any

            guard !slot.type.accepts(written, in: loweredTypes) else { continue }

            throw BuildError(
                "sending '\(call.selector)' with \(name),"
                    + " which holds \(written.rendered(in: loweredTypes))"
                    + " where \(slot.type.rendered(in: loweredTypes)) is declared",
                at: site.place.argument(name.spelling)
            )
        }

        // The receiver is written on the other side of the dot and checked the
        // same way.
        if
            let written = site.received,
            let name = declared.receiver,
            let slot = slot(name)
        {
            guard slot.type.accepts(written, in: loweredTypes) else {
                throw BuildError(
                    "sending '\(call.selector)' to \(written.rendered(in: loweredTypes)),"
                        + " where \(slot.type.rendered(in: loweredTypes)) is declared",
                    at: site.place.part(.receiver)
                )
            }
        }
    }
}
