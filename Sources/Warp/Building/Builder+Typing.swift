//
//  Builder+Typing.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What each name in a body holds, worked out by reading the body in order.
//
// An author binds a call to a name and passes the name, so a declared `returns`
// only reaches the next call site if the link knows what that name holds. This
// is what knows: `said = call counts` followed by `wants(procedure: said)` is two
// declarations disagreeing, and both are text.
//
// It is inference and not a type system. Nothing here is required to say
// anything: what cannot be read is `any`, and `any` is accepted everywhere a
// value is passed. A wrong answer would be a refusal an author cannot act on,
// so the walk answers only where the text says so.
//
// Reading through one is the exception, and it is the one place saying nothing
// is not enough: a dot needs a type to be judged against, so a dot on `any`
// refuses rather than deferring to the run. The author names the type with
// `as`, and the walk goes on from there.
//
// A path reads a name and nothing else, so every segment a document writes
// stays what it was written as. What each one lands on is judged here against
// the type the walk reached, and a dot on a type that declares no such field
// is refused rather than left for the run.
extension Builder {
    // MARK: - Internal
    // The environment a procedure's body starts from: its own parameters, which
    // are the only names declared before the first statement.
    func environment(of signature: Signature, in table: LoweredTypeTable) -> [Name: Binding] {
        signature.parameters.mapValues { parameter in Binding(parameter: parameter.declared.lowered(in: table)) }
    }

    // What a body hands its caller: the result it reads, and every `return`
    // that carried something out. The two ways a procedure answers, joined.
    // Read rather than judged, because this is asked of a body the walk may
    // read again, and a refusal here would be one the judging pass is about to
    // state in its own place.
    //
    // Named for the reading and not for the answer, because the sibling below
    // (what a *signature* answers) is the other question, and the two are kept
    // apart on purpose: one is what the author wrote and one is what the link
    // worked out.
    func reading(
        from block: Block,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext
    ) async throws -> LoweredType {
        let walked = try await inspected(
            block: block,
            at: place,
            in: environment,
            with: context,
            ask: .reading
        )

        return join(walked.flow.answered, walked.reading)
    }

    // What a body answers, held to the `returns` written beside it. A
    // declaration and a closure literal each write both in one document, so
    // each asks here rather than working the question out again further on.
    //
    // A reading that opens to `any`, which is what applying a value reaches,
    // stands and is settled where the value arrives. The refusal stands where
    // the author can act on it: at the `result` when one is written, and at
    // the `returns` when the body answers nothing at all.
    func held(
        _ read: LoweredType,
        to returns: TypeExpression?,
        resulting: Bool,
        at place: Place,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment?
    ) throws {
        guard let returns else { return }

        let promised = returns.lowered(in: table)

        guard promised.accepts(read, in: table) else {
            throw BuildError(
                "answers \(read.rendered(in: table)), and its"
                    + " declaration promises \(returns)",
                at: place.part(resulting ? .result : .returns)
            )
        }

        // A composition the declaration promises holds the answer to its
        // bounds the way a slot holds what arrives, wherever in the promise
        // it stands, and a parameter the promise mentions twice is answered
        // the same both times.
        if let refusal = refusal(
            holding: read,
            to: promised,
            as: "the answer holds",
            answering: true,
            in: table,
            fulfillment: fulfillment,
            at: place
        ) {
            throw BuildError(refusal, at: place.part(resulting ? .result : .returns))
        }
    }

    // Why what arrived is provably outside what a declaration holds it to,
    // wherever in the declaration a composition stands, or nothing. What
    // leans on a claim this table cannot settle is written down for the
    // link to settle.
    func refusal(
        holding given: LoweredType,
        to declared: LoweredType,
        as label: String,
        answering: Bool = false,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment?,
        at place: Place
    ) -> String? {
        var readings: [Name: LoweredType] = [:]
        var disagreeing: [Name: LoweredType] = [:]
        var holding: [Substitution.Held] = []

        declared.binding(against: given, into: &readings, disagreeing: &disagreeing, holding: &holding, in: table)

        if answering, !disagreeing.isEmpty {
            return disagreeing.keys.sorted().map { parameter in
                "'\(parameter)' is answered as \(readings[parameter]?.rendered(in: table) ?? "?")"
                    + " and as \(disagreeing[parameter]?.rendered(in: table) ?? "?")"
            }.joined(separator: ", ")
        }

        for held in holding {
            for bound in held.bounds {
                if let refusal = refusal(of: held.reading, holdingTo: bound, as: label, in: table, fulfillment: fulfillment, at: place) {
                    return refusal
                }
            }
        }

        return nil
    }

    // A block with every dot judged and every call gathered, each site carrying
    // what was in scope where it was written. Statements are read in order
    // because that is what a body means. A name holds what the statement before
    // it bound.
    func resolvedSites(
        in block: Block,
        at place: Place,
        in environment: [Name: Binding],
        answering returns: TypeExpression?,
        with context: TypingContext,
        folding: Folding?,
        origin: Int? = nil,
        writing fulfillment: Fulfillment
    ) async throws -> (block: Block, calls: [CallSite]) {
        let inner = try await inspected(
            block: block,
            at: place,
            in: environment,
            with: context,
            ask: .judging(folding: folding, origin: origin, writing: fulfillment)
        )

        try held(
            join(inner.flow.answered, inner.reading),
            to: returns,
            resulting: block.result != nil,
            at: place,
            in: context.loweredTypes,
            fulfillment: fulfillment
        )

        return (inner.block, inner.calls)
    }

    // The expression form. A constant's body is one rather than a block.
    func resolvedSites(
        in expression: Expression,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        folding: Folding?,
        writing fulfillment: Fulfillment
    ) async throws -> (Expression, [CallSite]) {
        let inner = try await inspected(
            expression,
            at: place,
            in: environment,
            with: context,
            ask: .judging(folding: folding, writing: fulfillment)
        )

        return (inner.rewritten, inner.calls)
    }

    // The one membership judgment every surface shares: call reads it over
    // the whole signature, a path over the receiver's slot. Answers the
    // refusal, or nil where every constrained parameter admits its reading.
    //
    // That one parameter takes one bound, and that a named bound is declared,
    // are the declaration's own facts. Held by
    // the judgment every signature passes where it is declared, before anything
    // gathers readings for this. Judging against every name in a mention set
    // costs nothing when the set holds its one.
    func constraintRefusal(
        mentions: [Name: [Name]],
        readings: [Name: LoweredType],
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment?,
        at place: Place
    ) -> String? {
        for (parameter, names) in mentions.sorted(by: { $0.key < $1.key }) {
            guard let reading = readings[parameter] else { continue }

            for name in names {
                // One nothing declares was refused where the declaration was
                // judged.
                guard let bound = loweredTypes.bound(named: name) else { continue }

                if let refusal = refusal(
                    of: reading,
                    holdingTo: bound,
                    as: "'\(parameter)' is read as",
                    in: loweredTypes,
                    fulfillment: fulfillment,
                    at: place
                ) {
                    return refusal
                }
            }
        }

        return nil
    }

    // Why a reading is provably outside one bound, or nothing where it is
    // not. A membership and a contract ask different questions of the same
    // reading: what a membership admits is a set of types, what a contract
    // asks is a set of procedures the reading's own type answers.
    func refusal(
        of reading: LoweredType,
        holdingTo bound: LoweredType.Bound,
        as label: String,
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment?,
        at place: Place
    ) -> String? {
        switch bound {
        case let .contract(name):
            switch loweredTypes.answering(contract: name, reading: reading) {
            // What leans on a claim is written down for the link to settle;
            // where nothing is written, it is held to what the documents say,
            // and what they have not said yet passes.
            case let .leansOn(types):
                guard let fulfillment else {
                    guard let unheld = types.first(where: { type in
                        loweredTypes.settles(contract: name, arrived: type) == false
                    }) else {
                        return nil
                    }

                    return "\(label) \(reading.rendered(in: loweredTypes)), and no document"
                        + " says '\(unheld)' answers every procedure '\(name)' asks"
                }

                for type in types {
                    fulfillment.require(Claim(type: type, contract: name), at: place)
                }

                return nil

            case .settled(true):
                return nil

            case .settled(false):
                return "\(label) \(reading.rendered(in: loweredTypes)),"
                    + " which does not answer every procedure '\(name)' asks"
            }

        case let .membership(row):
            guard !loweredTypes.admits(constraint: row, reading: reading, assuming: []) else { return nil }

            return "\(label) \(reading.rendered(in: loweredTypes)),"
                + " which '\(loweredTypes.constraintLabels[row])' does not admit"
        }
    }

    // The judgment every call shares, whichever surface writes it. A call
    // writes the arguments, a path writes only the receiver. What the readings
    // put in the declaration's type parameters is read once: a parameter read
    // two ways is refused rather than folded, a bounded one is judged against
    // its membership, and the declaration comes back with the readings filled.
    // One machine, so a surface added later cannot lose a step in the copying.
    enum Judgment {
        case fits(slots: [Slot], returns: LoweredType?)
        case refusal(String)
    }

    func judged(
        _ declared: Signature,
        over slots: [Slot],
        answering: LoweredType?,
        filledWith substitution: Substitution,
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment?,
        at place: Place
    ) -> Judgment {
        // A declaration with nothing to fill and nothing to hold is read as
        // the link lowered it. Lowering it again per call site is the same
        // answer paid for again, and this is the site every call goes through.
        guard declared.isGeneric || !substitution.holding.isEmpty else {
            return .fits(slots: slots, returns: answering)
        }

        guard substitution.disagreeing.isEmpty else {
            let named = substitution.disagreeing.keys.sorted().map { parameter in
                "'\(parameter)' is read as \(substitution.readings[parameter]?.rendered(in: loweredTypes) ?? "?")"
                    + " and as \(substitution.disagreeing[parameter]?.rendered(in: loweredTypes) ?? "?")"
            }

            return .refusal(named.joined(separator: ", "))
        }

        let bounds: [Name: [Name]]

        switch declared.parameterBounds {
        case let .held(held):
            bounds = held

        case let .disagreeing(parameter, one, other):
            return .refusal(Signature.ParameterBounds.refusal(parameter, one, other))
        }

        if let refusal = constraintRefusal(
            mentions: bounds,
            readings: substitution.readings,
            in: loweredTypes,
            fulfillment: fulfillment,
            at: place
        ) {
            return .refusal(refusal)
        }

        for (slot, held) in substitution.holding {
            for bound in held.bounds {
                if let refusal = refusal(
                    of: held.reading,
                    holdingTo: bound,
                    as: "'\(slot)' holds",
                    in: loweredTypes,
                    fulfillment: fulfillment,
                    at: place
                ) {
                    return .refusal(refusal)
                }
            }
        }

        guard declared.isGeneric else { return .fits(slots: slots, returns: answering) }

        return .fits(
            slots: declared.lowered(in: loweredTypes, filling: substitution.readings),
            returns: answering?.filling(substitution.readings)
        )
    }

    // What a call put in its callee's type parameters, read by holding each
    // declared parameter beside what was actually sent. The readings already in
    // hand, so nothing is walked a second time for the asking. A receiver is a
    // parameter written on the other side of the dot, so it is read the same
    // way.
    func substitution(
        of signature: Signature,
        over slots: [Slot],
        at call: Call,
        readings sent: [Name: LoweredType],
        receiver received: LoweredType?,
        in loweredTypes: LoweredTypeTable
    ) -> Substitution {
        var bound: [Name: LoweredType] = [:]
        var disagreeing: [Name: LoweredType] = [:]
        var holding: [(slot: Name, held: Substitution.Held)] = []

        func read(_ slot: Slot, as reading: LoweredType) {
            var held: [Substitution.Held] = []

            slot.type.binding(
                against: reading,
                into: &bound,
                disagreeing: &disagreeing,
                holding: &held,
                in: loweredTypes
            )

            holding += held.map { held in (slot: slot.name, held: held) }
        }

        for name in call.arguments.keys.sorted() {
            guard let slot = slots.first(where: { slot in slot.name == name }), let reading = sent[name] else {
                continue
            }

            read(slot, as: reading)
        }

        if let received,
           let name = signature.receiver,
           let slot = slots.first(where: { slot in slot.name == name }) {
            read(slot, as: received)
        }

        return Substitution(readings: bound, disagreeing: disagreeing, holding: holding)
    }

    // What a call answers: the declaration's returns, filled from the operands
    // where the declaration is generic. One statement of the rule, whichever
    // ask gathered the readings, and the operands are asked for lazily, so a
    // non-generic call never pays for taking them.
    private func answered(
        by signature: Signature?,
        over slots: [Slot],
        answering: LoweredType?,
        at call: Call,
        readings sent: @autoclosure () throws -> [Name: LoweredType],
        receiver received: @autoclosure () throws -> LoweredType?,
        in loweredTypes: LoweredTypeTable
    ) rethrows -> LoweredType {
        guard let signature, let returns = answering else { return .any }
        guard signature.isGeneric else { return returns }

        return returns.filling(
            substitution(
                of: signature,
                over: slots,
                at: call,
                readings: try sent(),
                receiver: try received(),
                in: loweredTypes
            ).readings
        )
    }

    // Where a path walk ended: the path with every dot's meaning written into
    // it and what the whole of it holds, or the refusal. One value for the two
    // answers, because they are read off one walk. A second walk for the
    // rewrite would be a second copy of the rules.
    enum PathReading {
        case reads([PathSegment], LoweredType)
        case refused(String)
    }

    // Walking a path through types the way the resolver walks it through
    // values. Each dot is judged by the type the walk has reached: a type
    // with fields reads one, a type without them sends a procedure, and the
    // judgment is spelled into the answered path (`key` for a read, `procedure` for
    // a call) so a run never asks the value.
    //
    // A field the type does not declare is refused, `?.` or not. The type
    // proved the absence, and a spelling that reads expected absence does not
    // overrule a proof. What may genuinely be absent at run (a `dictionary`
    // entry, a nullable's null) is where `?.` speaks: the plain spelling is
    // refused there, and the optional one answers null and makes the whole
    // path's reading nullable.
    //
    // Three types stop the walk, and each stops it for its own reason. On
    // `any` the walk **refuses**: nothing was declared, so there is nothing a
    // dot could be judged against, and a dot no declaration proves is what a
    // run would otherwise have to decide for itself. The type is named
    // instead, with `as`. On a type parameter the segments stand **as
    // written**: the type is declared, at the call rather than here, and what
    // the call filled in answers them. On `never` nothing arrives to be read at
    // all, so there is nothing to judge and nothing to refuse.
    func reading(
        of path: [PathSegment],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        writing fulfillment: Fulfillment?
    ) -> PathReading {
        if let refusal = path.markedHead { return .refused(refusal) }

        guard case let .key(head, _)? = path.first, let bound = environment[head] else {
            return asWritten(path, in: environment, with: context, at: place, writing: fulfillment)
        }

        var current = bound.type

        var resolved: [PathSegment] = [.key(head)]
        var walked: [PathSegment] = [.key(head)]

        // Whether an optional segment read past a possible absence. The one
        // thing that makes the whole path's answer nullable.
        var optional = false

        for (offset, segment) in path.dropFirst().enumerated() {
            current = context.resolve(current)
            walked.append(segment)

            // The segments after this one, as written. For the walks that stop
            // judging early.
            func rest() -> [PathSegment] {
                Array(path.dropFirst(offset + 2))
            }

            // Whether this segment's `?.` read past a possible absence. A
            // `?.` that read past nothing claims an absence the types rule
            // out, and a claim the text cannot keep is refused below the way
            // a needless `?` on a type spelling is.
            var unwrapped = false

            // What the dot lands on, settled: the walk-stopping types are
            // asked again after every unwrap, because what a `T?` holds is a
            // type like any other (`any`, null, another name, another nullable)
            // and an unwrap that skipped the questions would judge on a type
            // nobody checked.
            settling: while true {
                // Three types stop a walk, and they stop it for three
                // different reasons, so they are asked separately, and each
                // says its own. A dot is judged against what a declaration
                // proves at this site: `any` declares nothing and never will, a
                // type parameter's type is declared at the call, and `never`
                // declares a value that does not arrive at all.

                // Nothing was declared here, so nothing about this value can
                // ever be proven, and a dot the link cannot judge is the one
                // thing a run would have to decide for itself. The author says
                // what they expect and the reading goes on from there; the
                // type is theirs to name, not the value's to supply. An index
                // says as much as a dot does (that a type is there to be read
                // into) so it refuses here too, and says so in its own terms.
                // Before the three were told apart this arm let indexes through
                // to the run; that exception was a fact about the branch being
                // shared, not a decision about indexes, and keeping it would
                // leave the one rule saying `[` may read what `.` may not.
                if current == .any {
                    let reach = switch segment {
                    case .key: "reads a dot on"
                    case .index, .indexRef: "indexes into"
                    }

                    return .refused(
                        "\(walked.rendered) \(reach) \(current.rendered(in: context.loweredTypes)),"
                            + " which declares nothing."
                            + " A type is read by naming it, with `as`"
                    )
                }

                // A parameter is filled by the call, so the type *is*
                // declared. Elsewhere. That is why this is not `any`'s case and
                // does not refuse: the segments stand as written and the call's
                // type answers them, which is the decision
                // `ParameterReceiverTests` holds.
                //
                // What would make this judgeable here is the bound: a
                // constraint is a declared membership of concrete types, so a
                // dot every member admits is a dot this site could prove.
                // Reading it that way needs the walked signature's `bounds`,
                // which this walk is not given, so the fact is named here
                // rather than guessed at. The reading stays a type the call
                // decides, not `any`. Saying `any` would hand the next
                // statement a type the author never wrote. `x = item.a` then
                // `x.b` would refuse on `any` where `item.a.b` in one statement
                // stands, and naming a step is not supposed to change what a
                // path means.
                //
                // And not the parameter itself. `item` is the type the call
                // filled in; `item.a` is a field of that type, which is a
                // different unknown. Handing the parameter back made a walk
                // through one impersonate it: the field stood where `some T`
                // was asked for, and carried T's bound onto a value that never
                // earned it. `some N: Comparable` proving `item.a` comparable
                // on nothing but where it was read from.
                //
                // Where the walk reached is asked of the type it walked
                // through, not assembled from the segments written here: a
                // body may name a step on the way (`held = of.inner`, then
                // `held.count`), and the field it lands on is the same field
                // either way.
                if let reached = current.reaching([segment] + rest()) {
                    switch asWritten([segment] + rest(), in: environment, with: context, at: place, writing: fulfillment) {
                    case let .refused(reason):
                        return .refused(reason)

                    case let .reads(judged, _):
                        return .reads(resolved + judged, reached)
                    }
                }

                // Nothing arrives to be read, so there is nothing to judge and
                // nothing to refuse. The segments stand as written and the walk
                // stops. That the reading is unreachable is the leaving rules'
                // fact, said where they are said.
                if current == .never {
                    switch asWritten([segment] + rest(), in: environment, with: context, at: place, writing: fulfillment) {
                    case let .refused(reason):
                        return .refused(reason)

                    case let .reads(judged, _):
                        return .reads(resolved + judged, .never)
                    }
                }

                // Null stops the reading here exactly as it stops the run's.
                // One judge, owned by the segment, so the two layers say the
                // same sentence.
                if current == .null {
                    switch segment.meetingNull(at: walked) {
                    case let .refused(reason):
                        return .refused(reason)

                    case .reads:
                        break
                    }

                    switch asWritten([segment] + rest(), in: environment, with: context, at: place, writing: fulfillment) {
                    case let .refused(reason):
                        return .refused(reason)

                    case let .reads(judged, _):
                        return .reads(resolved + judged, .null)
                    }
                }

                guard case let .nullable(inner) = current else { break settling }

                guard segment.optional else {
                    return .refused(
                        "\(walked.rendered) reads into \(current.rendered(in: context.loweredTypes)),"
                            + " which may be null. Absence is read with"
                            + " `\(segment.mark)`"
                    )
                }

                optional = true
                unwrapped = true
                current = context.resolve(inner)
            }

            // Whether the mark the author wrote here had anything to read past.
            // Asked of the segment, which owns the rule and the sentence, so
            // the walk's landings cannot drift. Every landing asks, including
            // the one whose answer is always yes: a landing that skipped the
            // question would keep its own copy of the rule.
            func needless(_ landing: PathSegment.Landing) -> PathReading? {
                segment.needlessMark(
                    at: walked,
                    on: current.rendered(in: context.loweredTypes),
                    landing: landing,
                    unwrapped: unwrapped
                )
                .map { .refused($0) }
            }

            // What an index lands on, once the walk knows it is an array (or
            // bytes, an array in a compact spelling). An element past the end
            // is a defect at the run, not an absence, so `?[` says nothing
            // here unless it just unwrapped the array's own null.
            func indexed(_ element: LoweredType) -> PathReading? {
                if let refusal = needless(.element) { return refusal }

                current = element

                return nil
            }

            switch (segment, current) {
            // An index written as a reference is a name the run settles, which
            // element is read, not what the elements are. The name is a path of
            // its own, judged like one, and the walk goes on with the element
            // type the way a literal index does.
            case let (.indexRef(inner, optionally), .array(element)):
                switch indexReference(inner, in: environment, with: context, at: place, writing: fulfillment) {
                case let .refused(reason):
                    return .refused(reason)

                case let .judged(innerResolved):
                    if let refused = indexed(element) { return refused }

                    resolved.append(.indexRef(innerResolved, optional: optionally))
                }

            case let (.index, .array(element)):
                if let refused = indexed(element) { return refused }

                resolved.append(segment)

            // A dictionary's names are data, so a key the run settles reads an
            // entry the way a written key does. Absence follows the mark, the
            // rule every entry reading shares.
            case let (.indexRef(inner, optionally), .dictionary(entry)):
                switch keyReference(inner, in: environment, with: context, at: place, writing: fulfillment) {
                case let .refused(reason):
                    return .refused(reason)

                case let .judged(innerResolved):
                    if let refusal = needless(.entry) { return refusal }

                    if optionally { optional = true }

                    current = entry
                    resolved.append(.indexRef(innerResolved, optional: optionally))
                }

            case (.index, _), (.indexRef, _):
                return .refused(
                    "\(walked.rendered) indexes into \(current.rendered(in: context.loweredTypes)),"
                        + " and only an array or a dictionary is indexed"
                )

            // A dictionary holds entries of one type under names that are
            // data, so which names are there is a run's fact. `?.` reads an
            // absent one as null, and the plain spelling refuses it at run. The
            // rule is asked here like everywhere else and always answers yes:
            // the mark has an absence to expect on an entry, unwrapped or not,
            // and that fact lives in the rule rather than in this landing.
            case (.key, .dictionary(let entry)):
                if let refusal = needless(.entry) { return refusal }

                if segment.optional { optional = true }

                current = entry
                resolved.append(segment)

            // A dot on a record reads the field it declares. A field it does
            // not declare is a defect the text shows, refused here rather than
            // found at run, and so is a `?.` on one it does declare: the type
            // proves the field is there, so the spelling that expects absence
            // says nothing, unless it just read past the receiver's own null.
            case let (.key(key, _), .record(fields)):
                guard let field = fields[key] else {
                    return .refused(
                        "\(walked.rendered) names '\(key)',"
                            + " which \(current.rendered(in: context.loweredTypes)) does not declare."
                            + " A procedure is sent with a written call, and data"
                            + " past the declaration is read by declaring it,"
                            + " or through `dictionary<any>`"
                    )
                }

                if let refusal = needless(.field(key)) { return refusal }

                current = field.fieldUnwrapped
                resolved.append(segment)

            // A type with no fields has no name here to read. The procedure by
            // this spelling is sent with a written call, which names the
            // declaration it means.
            case let (.key(key, _), _):
                return .refused(
                    "\(walked.rendered) names '\(key)',"
                        + " and \(current.rendered(in: context.loweredTypes)) has no name there to read."
                        + " A procedure by that spelling is sent with a written call"
                )
            }
        }

        return .reads(resolved, optional ? nullableReading(of: current) : current)
    }

    // MARK: - Private
    private static let roundType = LoweredType.record(.round)

    // The segments a stopped walk hands back: as written, except that an index
    // reference is a path of its own and is judged wherever the outer walk
    // stops.
    private func asWritten(
        _ segments: [PathSegment],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        writing fulfillment: Fulfillment?
    ) -> PathReading {
        var judged: [PathSegment] = []

        for segment in segments {
            guard case let .indexRef(inner, optionally) = segment else {
                judged.append(segment)

                continue
            }

            switch indexReference(inner, in: environment, with: context, at: place, writing: fulfillment) {
            case let .refused(reason):
                return .refused(reason)

            case let .judged(innerResolved):
                judged.append(.indexRef(innerResolved, optional: optionally))
            }
        }

        return .reads(judged, .any)
    }

    // The one machine that judges an index reference, wherever a walk meets
    // one. The outer reading, a stopped walk's leftovers. The inner path is a
    // path of its own; what it reads has to be able to be an index. `int` is
    // one; `double` and a bounded parameter may hold a whole value the run accepts, so
    // only the actual reading (the fold's, or the run's) refuses the fraction;
    // what the walk could not read might be anything. Everything else provably
    // is not, and a text-proven defect is refused here.
    private enum IndexReading {
        case judged([PathSegment])
        case refused(String)
    }

    private func indexReference(
        _ inner: [PathSegment],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        writing fulfillment: Fulfillment?
    ) -> IndexReading {
        switch reading(of: inner, in: environment, with: context, at: place, writing: fulfillment) {
        case let .refused(reason):
            return .refused(reason)

        case let .reads(innerResolved, innerType):
            switch context.resolve(innerType) {
            case .int, .ranged, .double, .any, .never, .parameter:
                return .judged(innerResolved)

            default:
                return .refused(
                    "index reference \(inner.rendered) reads"
                        + " \(innerType.rendered(in: context.loweredTypes)), expected int"
                )
            }
        }
    }

    // The one machine that judges a key the run settles. A dictionary's names
    // are strings, so what stands between the brackets has to be able to be
    // one; what the walk could not read might be anything, and everything else
    // provably is not.
    private func keyReference(
        _ inner: [PathSegment],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        writing fulfillment: Fulfillment?
    ) -> IndexReading {
        switch reading(of: inner, in: environment, with: context, at: place, writing: fulfillment) {
        case let .refused(reason):
            return .refused(reason)

        case let .reads(innerResolved, innerType):
            switch context.resolve(innerType) {
            case .string, .any, .never, .parameter:
                return .judged(innerResolved)

            default:
                return .refused(
                    "key reference \(inner.rendered) reads"
                        + " \(innerType.rendered(in: context.loweredTypes)), expected string"
                )
            }
        }
    }

    // The inner index paths a fold can settle. `items[C]` reads its index from
    // a constant, so the index is knowable now and no constant name survives
    // into the image. Recursive, because an index path holds index paths of its
    // own (`items[names[C]]`) and the promise is about all of them.
    func foldedIndexReferences(
        _ segments: [PathSegment],
        at place: Place,
        folding: Folding
    ) async throws -> [PathSegment] {
        var folded: [PathSegment] = []

        for segment in segments {
            folded.append(try await self.folded(segment, at: place, folding: folding))
        }

        return folded
    }

    // One index path a fold settles. The recursion of the gathering above,
    // written out because reading a constant runs, and what runs is a call.
    private func folded(
        _ segment: PathSegment,
        at place: Place,
        folding: Folding
    ) async throws -> PathSegment {
        guard case let .indexRef(inner, optionally) = segment else { return segment }

        guard
            case let .key(head, _)? = inner.first,
            folding.holds(head)
        else {
            return .indexRef(
                try await foldedIndexReferences(inner, at: place, folding: folding),
                optional: optionally
            )
        }

        let settled: Value

        do {
            settled = try await folding.read(inner, at: place)
        } catch {
            throw BuildError("reading constant \'\(head)\': \(error)", at: place)
        }

        // The mark rides the fold: which element is read settles now,
        // whether the array is there to be read stays the run\'s question.
        switch settled {
        case let .int(index):
            return .index(index, optional: optionally)

        case let .double(fraction):
            switch Int.reading(fraction) {
            case let .int(whole):
                return .index(whole, optional: optionally)

            case .notANumber, .fractional:
                throw BuildError(
                    "index reference \(inner.rendered) is not a whole number",
                    at: place
                )

            case .overflow:
                throw BuildError(
                    "index reference \(inner.rendered) indexes past the end of any array",
                    at: place
                )
            }

        default:
            throw BuildError(
                "index reference \(inner.rendered) is \(settled.type), expected int",
                at: place
            )
        }
    }

    // What a path that read past a possible absence holds. Wrapping what
    // already admits null would say the one fact twice.
    private func nullableReading(of type: LoweredType) -> LoweredType {
        switch type {
        case .any, .null, .nullable:
            return type

        default:
            return .nullable(type)
        }
    }

    // What ran inside an expression may have written the enclosing names. The
    // one thing a nested body does that the body around it has to know about,
    // because a write is to a box the enclosing body holds. Flow gathers those
    // writes with the one distinction the reading after needs: whether every
    // finishing way through made the write. A definite write retypes the name;
    // an indefinite one joins with what the name held.
    private struct Flow {
        var written: [Name: (type: LoweredType, definite: Bool)] = [:]

        // What was written on ways that left. It flows past nothing here (no
        // run comes back from a leave) but a `break` ends only its loop and an
        // attempt's body only its attempt, so the construct that absorbs the
        // leave puts these back in play. Nothing about an escaped write is ever
        // certain, and the type says so by having no room for the claim. A flow
        // that leaves holds everything it wrote here and nothing under
        // `written`.
        var escaped: [Name: LoweredType] = [:]

        // Whether every way through leaves.
        var leaves = false

        // What a `return` inside here carried out of the procedure. Nothing
        // absorbs one (a loop ends its rounds and an attempt its body, and
        // neither is what a `return` reaches) so this only ever gathers on the
        // way up, and what it gathers is the other half of what the procedure
        // answers: the result the block reads is one way out, and every
        // `return` is another.
        //
        // Beside `escaped` rather than folded into it: an escaped write is
        // about a name the body around this one holds, and this is about the
        // value the procedure hands its caller.
        var answered: LoweredType?
    }

    // Two answers, either of which may not be there. The join, said once, for
    // the places that gather what a body hands back.
    private func joined(_ left: LoweredType?, _ right: LoweredType?) -> LoweredType? {
        guard let right else { return left }

        return join(left, right)
    }

    // The one statement of how a write lands. On what an earlier write left,
    // and on what a name held. A definite write replaces; an indefinite one may
    // not have happened, so it joins with what was there, and whether the name
    // was written at all stays the earlier fact. Every place a Flow meets an
    // environment or another Flow reads these two, so the rule cannot drift one
    // copy at a time.
    private func merged(
        _ held: (type: LoweredType, definite: Bool)?,
        with later: (type: LoweredType, definite: Bool)
    ) -> (type: LoweredType, definite: Bool) {
        guard let held, !later.definite else { return later }

        return (join(held.type, later.type), held.definite)
    }

    private func apply(_ flowed: Flow, to environment: inout [Name: Binding]) {
        for (name, write) in flowed.written {
            // A flow writes boxes, and a box that declared its type was
            // checked where it was written, so a write into it changes
            // nothing about what it holds.
            guard case let .assigned(held)? = environment[name] else { continue }

            environment[name] = .assigned(
                write.definite
                    ? write.type
                    : join(held, write.type)
            )
        }
    }

    // The two asks the one walk answers. Judging is the link's own pass (every
    // dot rewritten, every call gathered, every refusal thrown) and it happens
    // once per site. Reading answers the type and flow questions alone and
    // refuses nothing (what cannot be read is `any`) because its askers read a
    // body out of place or more than once: an operand typed where it stands, a
    // round re-read until its writes settle, where a refusal would be transient
    // or repeated. One walk under two asks, so the rules cannot drift a copy at
    // a time, and so a body is read once, where a walk per question would
    // compound arm by arm into an exponential reading of nothing new.
    private enum Ask {
        // Judging carries which module the body being judged was declared
        // in, where it was declared in one; a constant's expression has no
        // module to read its variables by.
        case judging(folding: Folding?, origin: Int? = nil, writing: Fulfillment? = nil)
        case reading

        // Where a walk writes down the pairs its calls lean on. A walk that
        // reads rather than judges has none, so a probe cannot write.
        var fulfillment: Fulfillment? {
            guard case let .judging(_, _, fulfillment) = self else { return nil }

            return fulfillment
        }

        // Whether this ask keeps what the walk rebuilds. Reading reads a body
        // out of place or more than once, so it hands the expression back as
        // written instead of paying for a copy nobody takes. In an expression
        // case the pieces are gathered either way, so a gate there only spares
        // the final assembly, but a loop or a walk also asks this to choose
        // between the settled probe and a judging re-walk, and that choice
        // carries refusals and gathered sites, so it is not one to drop.
        var rewrites: Bool {
            if case .judging = self { return true }

            return false
        }
    }

    // The gate a refusal passes: judging throws it, and the reading ask has
    // none to throw. A refusal the walk states passes here, so it cannot forget
    // which ask refuses, and what remains after it under reading is the
    // degraded answer beside each call. The constant-folding throws stand apart
    // on purpose: a folding scope rides only the judging ask, so those are
    // judging's by construction.
    private func refuse(
        _ reason: @autoclosure () -> String,
        at place: Place,
        when ask: Ask
    ) throws {
        guard case .judging = ask else { return }

        throw BuildError(reason(), at: place)
    }

    // A constant settles at the build, so what it is written from is read
    // rather than run. The same gate an operand passes, asked where a constant
    // is settled, because those are the two places the build reads an
    // expression instead of running it.
    func settles(
        _ expression: Expression,
        at place: Place,
        given context: TypingContext,
        writing fulfillment: Fulfillment
    ) throws {
        try held(
            expression,
            asOperand: place,
            given: context,
            when: .judging(folding: nil, origin: nil, writing: fulfillment)
        )
    }

    // An operand is data: the run reads it rather than running it. A call to a
    // declaration that answers only by running is refused here, where the
    // operand is written, rather than found when the reading reaches it.
    private func held(
        _ expression: Expression,
        asOperand place: Place,
        given context: TypingContext,
        when ask: Ask
    ) throws {
        switch runs(in: expression, given: context) {
        case nil:
            return

        case let .calling(selector)?:
            try refuse(
                "reads '\(selector)', which answers only by running, and an"
                    + " operand is read rather than run. A procedure that runs"
                    + " is called by a statement, whose name the operand reads",
                at: place,
                when: ask
            )

        case .applying?:
            try refuse(
                "calls a value, and which procedure that is, is the run's"
                    + " answer, so an operand cannot be read without running"
                    + " it. A statement calls it and the operand reads its name",
                at: place,
                when: ask
            )

        case .construct?:
            try refuse(Expression.constructInOperand, at: place, when: ask)
        }
    }

    // A condition chooses a way through a body, so what it reads has to be a
    // bool. `any` passes, the way it passes every other slot: nothing was
    // declared, and the run judges what arrives.
    private func held(
        _ reading: LoweredType,
        asCondition place: Place,
        in context: TypingContext,
        when ask: Ask
    ) throws {
        guard !LoweredType.bool.accepts(reading, in: context.loweredTypes) else { return }

        try refuse(
            "reads \(reading.rendered(in: context.loweredTypes)), and a condition"
                + " chooses a way through a body, so it answers a bool",
            at: place,
            when: ask
        )
    }

    // One walk's answers: the expression with every dot's meaning written
    // in, the sends gathered on the way, what the whole of it holds, and
    // what it wrote to the names around it. The reading ask hands the
    // expression back as written and gathers nothing.
    private struct Inspection {
        var rewritten: Expression
        var calls: [CallSite] = []
        var reading: LoweredType
        var flow = Flow()
    }

    // The walk. Each subexpression is judged in the environment the ones
    // before it left behind, which is the environment the run gives it.
    private func inspected(
        _ expression: Expression,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> Inspection {
        switch expression {
        case let .literal(value):
            return Inspection(rewritten: expression, reading: type(of: value, in: context.loweredTypes))

        // Nothing comes back from here, so there is no value to have a type.
        // `never` fits wherever it is written, and what evaluating the carried
        // value wrote left with the leave.
        case let .leave(leave):
            // What the procedure answers this way. Only a `return` reaches the
            // caller (a `break` ends its loop and a `continue` its round) and
            // one carrying nothing hands back the null a body with no result
            // hands back, which is the run's own answer for it.
            func answering(_ flowed: Flow, carrying carried: LoweredType?) -> Flow {
                guard leave.reach == .procedure else { return flowed }

                var answering = flowed
                answering.answered = joined(flowed.answered, carried ?? .null)

                return answering
            }

            guard let value = leave.value else {
                return Inspection(
                    rewritten: expression,
                    reading: .never,
                    flow: leaving(answering(Flow(), carrying: nil))
                )
            }

            let carried = try await inspected(value, at: place, in: environment, with: context, ask: ask)

            return Inspection(
                rewritten: ask.rewrites
                    ? .leave(
                        Leave(reach: leave.reach, target: leave.target, value: carried.rewritten)
                    )
                    : expression,
                calls: carried.calls,
                reading: .never,
                flow: leaving(answering(carried.flow, carrying: carried.reading))
            )

        // A path names something that has to exist just as a selector does, so
        // judging refuses what does not resolve, and the judgment is the
        // rewrite that fixes what each dot means. A constant-headed path is
        // data the moment it is read, so under a folding scope it is judged
        // first (the same rules as any path) and then becomes that data.
        case let .reference(path):
            switch reading(of: path, in: environment, with: context, at: place, writing: ask.fulfillment) {
            case let .refused(reason):
                try refuse(reason, at: place, when: ask)

                return Inspection(rewritten: expression, reading: .any)

            case let .reads(resolved, read):
                guard case let .judging(folding, _, _) = ask else {
                    return Inspection(rewritten: expression, reading: read)
                }

                guard let folding else {
                    return Inspection(rewritten: .reference(resolved), reading: read)
                }

                // An inner index path may read a constant too. `items[C]` folds
                // its index the way a whole constant path folds, so no constant
                // name survives into the image.
                let settled = try await foldedIndexReferences(resolved, at: place, folding: folding)

                guard
                    case let .key(head, _)? = settled.first,
                    folding.holds(head)
                else {
                    return Inspection(rewritten: .reference(settled), reading: read)
                }

                do {
                    let value = try await folding.read(settled, at: place)

                    return Inspection(rewritten: .literal(value), reading: type(of: value, in: context.loweredTypes))
                } catch {
                    throw BuildError("reading constant '\(head)': \(error)", at: place)
                }
            }

        case let .array(array):
            var environment = environment
            var rewritten: [Expression] = []
            var calls: [CallSite] = []
            var flowed = Flow()
            var element: LoweredType?

            for (position, member) in array.enumerated() {
                let inner = try await inspected(
                    member,
                    at: place.index(position),
                    in: environment,
                    with: context,
                    ask: ask
                )

                apply(inner.flow, to: &environment)
                flowed = sequenced(flowed, then: inner.flow)
                calls += inner.calls
                element = join(element, inner.reading)
                rewritten.append(inner.rewritten)
            }

            return Inspection(
                rewritten: ask.rewrites ? .array(rewritten) : expression,
                calls: calls,
                reading: .array(element ?? .any),
                flow: flowed
            )

        // A cast is where a reading the walk could not judge becomes one it
        // can. The type is the author's claim, so it is the reading from here
        // on, and the run is left the one question the link cannot answer,
        // which is what actually arrived.
        //
        // A claim the types already prove is refused, for the reason a needless
        // `?.` is: the mark of a doubt where no doubt is left says nothing, and
        // a spelling that says nothing is a reading gone wrong. `as: any` lands
        // here too, and rightly. Every reading fits it.
        case let .cast(value, type, optional):
            let inner = try await inspected(
                value,
                at: place.part(.receiver),
                in: environment,
                with: context,
                ask: ask
            )
            if optional, Builder.handedOnce(type, in: context.types) {
                try refuse(
                    "reads a value as '\(type.rendered)', which is handed on exactly"
                        + " once, and may answer nothing. \(Builder.followedByAName)",
                    at: place,
                    when: ask
                )
            }

            let claim = type.lowered(in: context.loweredTypes)
            let settled = claim.resolved(in: context.loweredTypes)

            let read = inner.reading.resolved(in: context.loweredTypes)

            // Both refusals ask the types themselves, with nothing gating them
            // on whether the reading is fully proven. A gate like that turned
            // the judgment off wherever `any` sat anywhere inside the reading
            // (`array<any>` read as `string` passed the link and answered null
            // on every run, the permanent silent null this spelling exists
            // against) while the case it was meant to protect (`{ data: any }`
            // read as `{ data: { name: string } }`) is one `couldBothHold`
            // already answers on its own, at the field.
            //
            // Needless means the claim and the reading are the same type, not
            // that one would accept the other. `accepts` is assignability, and
            // assignability is where a boundary still has work to do: it holds
            // between `int` and `int(0...10)`, and between anything and `any`,
            // precisely because the value is checked when it arrives. Reading
            // it as proof called every narrowing cast needless and left the
            // author no way to say what they knew.
            //
            // The claim is judged first, and on itself: a cast onto a type
            // that proves nothing opens no door, whatever it was written over.
            // What the claim names is judged where every cast is seen, in the
            // declaration scan. A spelling says that much on its own, and
            // asking it here would ask only of what this walk reaches. What is
            // left is the pair of questions that need the reading.
            //
            // The reading this cast hands on, worked out before the sameness
            // question so that question can ask about what is handed on
            // rather than about the spelling that produced it.
            let handed = optional && !claim.declaresNull(in: context.loweredTypes)
                ? LoweredType.nullable(claim)
                : claim

            // A declared record is a name as well as a structure: reading a
            // nameless record as one attaches the name, so it is never a
            // cast of what the value already is. Two names never hold one
            // value, and the unresolved types are asked so that is seen.
            let nominal = context.loweredTypes.record(of: claim) != nil

            if !claim.couldBothHold(inner.reading, in: context.loweredTypes) {
                // Neither could ever be the other, and the reading proves what
                // it is, so this cast cannot succeed on any run. `as` would
                // refuse every time and `as?` would answer null every time,
                // which is the silent permanent null `as?` exists to avoid
                // being. What is decidable before a run is decided before it.
                try refuse(
                    "reads \(inner.reading.rendered(in: context.loweredTypes)) as \(settled.rendered(in: context.loweredTypes)),"
                        + " and no value is both."
                        + " A cast names a type the value may turn out to"
                        + " have, and this one it never can",
                    at: place,
                    when: ask
                )
            } else if inner.reading == claim
                || (!nominal && (settled == read || handed.resolved(in: context.loweredTypes) == read)) {
                // Asked of the reading this hands on, not of the spelling that
                // made it. `payload as? int` hands on `int?` and `payload as?
                // Maybe` hands on `Maybe`. The same type by two spellings, and
                // reading the question off the spelling let the second catch a
                // repeat that the first waved through.
                try refuse(
                    "reads \(inner.reading.rendered(in: context.loweredTypes)) as \(settled.rendered(in: context.loweredTypes)),"
                        + " which it already is."
                        + " A cast opens what the types do not prove,"
                        + " and here they do",
                    at: place,
                    when: ask
                )
            }

            return Inspection(
                // The author's spelling stands. `settled` is what the judgment
                // needed (a name walked through to the type it declares) and
                // writing that back into the program would spend the name: a
                // refusal would read `as { age: int }` where the author wrote
                // `as Person`, and a document written back out would have lost
                // the declaration it leaned on. The run resolves names itself,
                // so nothing needs it resolved early.
                rewritten: ask.rewrites
                    ? .cast(inner.rewritten, as: type, optional: optional)
                    : expression,
                calls: inner.calls,
                // The author's spelling here too, and for the same reason it
                // stands in what is written back: a refusal on the next
                // statement quotes this reading, and quoting a type nobody
                // wrote (`{ name: string }` where the author wrote `Person`) is
                // the same name spent, one step later. Every consumer resolves
                // names itself. `?` is asked of the fact: a name standing for a
                // nullable already holds null, and wrapping it again would make
                // the same type read as two different ones depending on
                // whether the author wrote the name or what it stands for.
                reading: handed,
                flow: inner.flow
            )

        // In name order. The order the run evaluates fields in, so what one
        // field's write means to the next is the same fact at the run.
        case let .record(record):
            var environment = environment
            var rewritten: [Name: Expression] = [:]
            var calls: [CallSite] = []
            var flowed = Flow()
            var fields: [Name: LoweredType] = [:]

            for (name, field) in record.sorted { $0.key < $1.key } {
                let inner = try await inspected(
                    field,
                    at: place.key(name.spelling),
                    in: environment,
                    with: context,
                    ask: ask
                )

                apply(inner.flow, to: &environment)
                flowed = sequenced(flowed, then: inner.flow)
                calls += inner.calls
                fields[name] = inner.reading
                rewritten[name] = inner.rewritten
            }

            return Inspection(
                rewritten: ask.rewrites ? .record(rewritten) : expression,
                calls: calls,
                reading: .record(fields),
                flow: flowed
            )

        // A closure literal carries the signature it declared, and running one
        // is not this flow's business. What it writes it writes when it is
        // called, and the flow here is the flow of the making. Judging still
        // follows the body even though nothing can say whether it is ever
        // called: the warrant is compilation, and a body that never runs still
        // has to compile. It sees what surrounds it plus what it declares.
        // Constness is read the same way a declaration's is. From what the body
        // calls.
        case let .closure(procedure):
            var rewritten = expression
            var calls: [CallSite] = []
            var body = procedure.block

            if case .judging = ask, let written = procedure.block {
                let inner = try await inspected(
                    block: written,
                    at: place.part(.closure),
                    in: environment.merging(self.environment(of: procedure.signature, in: context.loweredTypes)) {
                        _, new in new
                    },
                    with: context,
                    ask: ask
                )

                // What the closure writes into a name it captured has to fit
                // what the name holds: the closure runs when it is called,
                // and the body that declared the variable reads it as the
                // type it gave it. A write here retypes nothing outside.
                for (name, write) in inner.flow.written.sorted(by: { $0.key < $1.key }) {
                    guard let held = environment[name]?.type else { continue }

                    guard held.accepts(write.type, in: context.loweredTypes) else {
                        throw BuildError(
                            "writes '\(name)', which it captured, as"
                                + " \(write.type.rendered(in: context.loweredTypes)). The body it captured"
                                + " from holds it as \(held.rendered(in: context.loweredTypes))",
                            at: place.part(.closure)
                        )
                    }

                    if let refusal = refusal(
                        holding: write.type,
                        to: held,
                        as: "writes '\(name)', which it captured, as",
                        in: context.loweredTypes,
                        fulfillment: ask.fulfillment,
                        at: place.part(.closure)
                    ) {
                        throw BuildError(refusal, at: place.part(.closure))
                    }
                }

                try held(
                    join(inner.flow.answered, inner.reading),
                    to: procedure.signature.returns,
                    resulting: written.result != nil,
                    at: place.part(.closure),
                    in: context.loweredTypes,
                    fulfillment: ask.fulfillment
                )

                body = inner.block
                calls = inner.calls
            }

            var reading: Set<Name> = []

            if case .judging(_, _?, _) = ask {
                reading = context.variables
            }

            // A name this closure captured carries what the slot it came from
            // said about it. The claim is the slot's, so it stands wherever the
            // name is read, and a closure that applies a captured one is judged
            // on that word exactly as the body around it would be. A box that
            // may be retyped after the capture says nothing the closure can
            // hold on to; one that declared its type holds it through every
            // write.
            let captured = environment.compactMapValues { bound -> LoweredType? in
                if case .assigned = bound { return nil }

                return bound.type
            }.filter { _, held in
                held.isConstProcedure || held.isIsolatedProcedure
            }

            let const = body.map { block in
                isConst(
                    block,
                    given: context.isConst,
                    reading: reading,
                    applying: procedure.signature.constProcedures
                        .union(captured.filter { _, held in held.isConstProcedure }.keys)
                )
            } ?? false
            let isolated = body.map { block in
                isIsolated(
                    block,
                    declaring: Set(procedure.signature.parameters.keys),
                    given: context.isIsolated,
                    applying: procedure.signature.isolatedProcedures
                        .union(captured.filter { _, held in held.isIsolatedProcedure }.keys),
                    taking: { selector in context.signature(of: selector) }
                )
            } ?? false

            if case .judging = ask, let body {
                rewritten = .closure(
                    Procedure(
                        description: procedure.description,
                        signature: procedure.signature,
                        implementation: .body(body),
                        constness: const ? .const : .unstated,
                        isolation: isolated ? .isolated : .unstated,
                        failing: failing(body, given: context.failing(of:))
                    )
                )
            }

            return Inspection(
                rewritten: rewritten,
                calls: calls,
                reading: TypeExpression.procedure(
                    procedure.signature,
                    const ? .const : .unstated,
                    isolated ? .isolated : .unstated
                )
                .lowered(in: context.loweredTypes)
            )

        // Which value is called is settled at run time, so nothing here can say
        // what it answers. Its operands are data the const resolver reads (the
        // check refuses a construct in one, and a program that came straight to
        // the link meets the same predicate here) so nothing writes and there
        // is no flow to carry.
        case let .apply(callee, arguments):
            guard case .judging = ask else {
                return Inspection(rewritten: expression, reading: .any)
            }

            // Named one by one, because a loop over the values alone reports
            // the third operand from the place the first was.
            try held(callee, asOperand: place.part(.callee), given: context, when: ask)

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                try held(argument, asOperand: place.argument(name.spelling), given: context, when: ask)
            }

            let called = try await inspected(
                callee,
                at: place.part(.callee),
                in: environment,
                with: context,
                ask: ask
            )
            var rewritten: [Name: Expression] = [:]
            var calls = called.calls

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                let inner = try await inspected(
                    argument,
                    at: place.argument(name.spelling),
                    in: environment,
                    with: context,
                    ask: ask
                )

                rewritten[name] = inner.rewritten
                calls += inner.calls
            }

            return Inspection(
                rewritten: .apply(called.rewritten, arguments: rewritten),
                calls: calls,
                reading: .any
            )

        // A call answers what its callee declared, which is the fact this whole
        // walk exists to carry. A declaration with a type parameter in it
        // answers nothing until this call fills it, so the parameters are read
        // from what was actually sent and the answer comes back with them
        // filled, and only a generic answer reads the operands at all, so under
        // the reading ask only a generic call pays for taking their readings.
        // The operands are data the const half reads (the check holds a
        // construct out of them, and the link asks the same predicate itself)
        // so nothing here writes: every operand stands in the one environment
        // the call stands in.
        case let .call(call):
            let signature = context.signature(of: call.selector)
                ?? context.contractProcedures[call.selector]?.signature

            guard case .judging = ask else {
                var readings: [Name: LoweredType] = [:]

                for argument in call.arguments {
                    readings[argument.key] = try await inspected(
                        argument.value,
                        at: place.argument(argument.key.spelling),
                        in: environment,
                        with: context,
                        ask: ask
                    ).reading
                }

                var receiver: LoweredType?

                if let written = call.receiver {
                    receiver = try await inspected(
                        written,
                        at: place.part(.receiver),
                        in: environment,
                        with: context,
                        ask: ask
                    ).reading
                }

                return Inspection(
                    rewritten: expression,
                    reading: try answered(
                        by: signature,
                        over: context.slots(of: call.selector),
                        answering: context.answer(of: call.selector),
                        at: call,
                        readings: readings,
                        receiver: receiver,
                        in: context.loweredTypes
                    )
                )
            }

            // Every operand of this call, judged before the walk splits on what
            // the selector names: what a slot takes has nothing to do with
            // whether the operand written into it is read or run. Named one by
            // one, because a loop over the values alone reports the third
            // operand from the place the first was.
            if let written = call.receiver {
                try held(written, asOperand: place.part(.receiver), given: context, when: ask)
            }

            for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
                try held(argument, asOperand: place.argument(name.spelling), given: context, when: ask)
            }

            // A call through a contract names no declaration. What answers it
            // is the receiver's own type, so it is judged here against what
            // the contract said and nowhere against a callee.
            if let asked = context.contractProcedures[call.selector] {
                return try await inspected(
                    contract: asked,
                    call: call,
                    at: place,
                    in: environment,
                    with: context,
                    ask: ask
                )
            }

            // A selector no module declares is refused where the walk meets
            // it. Its answer is unknown, and a dot on an unknown answer would
            // be refused first for what the dot reads, which is not what the
            // author got wrong.
            guard let callee = context.declared(call.selector) else {
                throw BuildError(
                    "sends '\(call.selector)', which no module in this link declares",
                    at: place
                )
            }

            var receiver: Inspection?

            if let written = call.receiver {
                receiver = try await inspected(
                    written,
                    at: place.part(.receiver),
                    in: environment,
                    with: context,
                    ask: ask
                )
            }

            var arguments: [Name: Expression] = [:]
            var sent: [Name: LoweredType] = [:]
            var calls = receiver?.calls ?? []

            for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
                let inner = try await inspected(
                    argument,
                    at: place.argument(name.spelling),
                    in: environment,
                    with: context,
                    ask: ask
                )

                arguments[name] = inner.rewritten
                sent[name] = inner.reading
                calls += inner.calls
            }

            try handedInPlace(
                by: call,
                to: callee.signature,
                in: environment,
                with: context,
                at: place,
                when: ask
            )

            let rewritten = Call(
                receiver: receiver?.rewritten,
                selector: call.selector,
                arguments: arguments
            )

            return Inspection(
                rewritten: .call(rewritten),
                calls: [
                    CallSite(
                        call: rewritten,
                        place: place,
                        callee: call.selector,
                        readings: sent,
                        received: receiver?.reading
                    )
                ] + calls,
                reading: answered(
                    by: signature,
                    over: context.slots(of: call.selector),
                    answering: context.answer(of: call.selector),
                    at: call,
                    readings: sent,
                    receiver: receiver?.reading,
                    in: context.loweredTypes
                )
            )

        case let .block(block):
            let inner = try await inspected(block: block, at: place, in: environment, with: context, ask: ask)

            return Inspection(
                rewritten: ask.rewrites ? .block(inner.block) : expression,
                calls: inner.calls,
                reading: inner.reading,
                flow: inner.flow
            )

        // A conditional answers nothing. A condition chooses a way through the
        // body, not a value; the one thing its type still says is `never`, when
        // both arms have it. The condition runs every way and the arms are the
        // fork, judged in the environment the condition left: an arm every run
        // takes does not exist unless both are written (a conditional with no
        // other arm makes every write indefinite) and an arm that leaves hands
        // on nothing, so the write the staying arm makes is definite again: the
        // ways that finish all made it. Unreached arms are followed on purpose.
        case let .conditional(condition, then, otherwise):
            if condition.holdsConstruct {
                try refuse(
                    Expression.constructInCondition,
                    at: place.part(.condition(of: .conditional)),
                    when: ask
                )
            }

            // A condition is data and writes nothing (the construct rule above
            // is what makes that a fact) so the arms stand in the environment
            // the conditional stands in.
            let head = try await inspected(
                condition,
                at: place.part(.condition(of: .conditional)),
                in: environment,
                with: context,
                ask: ask
            )

            try held(condition, asOperand: place.part(.condition(of: .conditional)), given: context, when: ask)
            try held(head.reading, asCondition: place.part(.condition(of: .conditional)), in: context, when: ask)

            let inside = environment

            let taken = try await inspected(then, at: place.part(.then), in: inside, with: context, ask: ask)

            guard let otherwise else {
                return Inspection(
                    rewritten: ask.rewrites
                        ? .conditional(head.rewritten, then: taken.body, else: nil)
                        : expression,
                    calls: head.calls + taken.calls,
                    reading: .null,
                    flow: sequenced(head.flow, then: either(taken.flow, or: Flow()))
                )
            }

            let declined = try await inspected(
                otherwise,
                at: place.part(.otherwise),
                in: inside,
                with: context,
                ask: ask
            )

            return Inspection(
                rewritten: ask.rewrites
                    ? .conditional(head.rewritten, then: taken.body, else: declined.body)
                    : expression,
                calls: head.calls + taken.calls + declined.calls,
                reading: taken.reading == .never && declined.reading == .never ? .never : .null,
                flow: sequenced(head.flow, then: either(taken.flow, or: declined.flow))
            )

        // A loop answers its body's declared result, and null when it has none.
        // A round may run no time at all, so nothing a round writes is
        // definite, and the leaves a round takes stop here, `break` and
        // `continue` being the loop's own, so they are absorbed rather than
        // handed on. A round also follows other rounds, so the condition and
        // the body read the settled environment. The one the rounds' own writes
        // have already joined into. Readings that cycle instead of settling
        // would be widened to `any` behind the author's back. Judging says so
        // out loud, where a refusal can carry the reason; the reading ask stays
        // total and takes the widened answer.
        case let .loop(condition, body, round):
            // A condition is data the run reads rather than runs, the fact every
            // operand has, so a construct is refused there by the same predicate, at
            // the check and here alike.
            if condition.holdsConstruct {
                try refuse(Expression.constructInCondition, at: place.part(.condition(of: .loop)), when: ask)
            }

            // The fixpoint probes the statements alone. The rounds are what
            // leave things for one another, and the result never runs between
            // rounds. The probe reads, so a reading asker takes the settled
            // probe as its own walk; judging walks once more for the rewrite.
            let (seeded, probed, converged) = try await settled(
                from: rounded(environment, as: round)
            ) { entry -> (round: BodyWalk, flow: Flow) in
                let walk = try await inspected(
                    body.body,
                    at: place.part(.body),
                    in: entry,
                    with: context,
                    ask: .reading
                )

                return (walk, walk.flow)
            }

            if !converged {
                try refuse(
                    "the names this loop writes never settle"
                        + " into one reading, so the build cannot say what"
                        + " they hold",
                    at: place,
                    when: ask
                )
            }

            let head = try await inspected(
                condition,
                at: place.part(.condition(of: .loop)),
                in: seeded,
                with: context,
                ask: ask
            )

            try held(condition, asOperand: place.part(.condition(of: .loop)), given: context, when: ask)
            try held(head.reading, asCondition: place.part(.condition(of: .loop)), in: context, when: ask)

            let rounds = ask.rewrites
                ? try await inspected(body.body, at: place.part(.body), in: seeded, with: context, ask: ask)
                : probed

            // The result runs once, at whichever exit the run takes (a
            // condition that declines at the start, a round that finishes or
            // breaks) and it reads in the join of those exits: the entry the
            // rounds seeded, joined with the environment the statements leave.
            // A name the body declared is the body's own, whatever the entry
            // holds under that spelling, and is null at the 0-round exit (a
            // name a scope does not hold reads as null) so it reads back
            // nullable, the same join every some-ways write gets. Of the
            // entry's names only a box the rounds retyped moves: one that
            // declared its type held every write to it.
            var tail: Inspection?

            if let result = body.result {
                var exit = seeded

                for (name, written) in rounds.environment {
                    if rounds.locals.contains(name) {
                        exit[name] = written.map { type in join(.null, type) }
                    } else if case let .assigned(entry)? = seeded[name] {
                        exit[name] = .assigned(join(entry, written.type))
                    }
                }

                tail = try await inspected(result, at: place.part(.result), in: exit, with: context, ask: ask)
            }

            return Inspection(
                rewritten: ask.rewrites
                    ? .loop(
                        while: head.rewritten,
                        body: Block(body: rounds.body, result: tail?.rewritten ?? body.result),
                        round: round
                    )
                    : expression,
                calls: head.calls + rounds.calls + (tail?.calls ?? []),
                reading: tail?.reading ?? .null,
                flow: sequenced(
                    head.flow,
                    then: tail.map { tail in
                        sequenced(absorbed(rounds.flow), then: tail.flow)
                    } ?? absorbed(rounds.flow)
                )
            )

        // The body and the rescue are two ways through, not a sequence. A body
        // that fails midway made some of its writes and the rescue runs then,
        // so what either side wrote may be there, whichever way ran and however
        // far it got. That is the environment the rescue reads as well as the
        // one it writes. No write on either side is definite, and the leaving
        // of either way says nothing about the whole: a body that always leaves
        // can still fail before its leave, and the rescue may finish normally,
        // so both sides' leaves are absorbed here, partial writes and all.
        case let .attempt(block, rescue, failure):
            // What the rescue is there for. A body nothing can fail out of
            // leaves it a body no run reaches, and the author wrote it
            // expecting otherwise: what they are told is which failures the
            // link found, which is none.
            if failing(block, given: context.failing(of:)).failsNothing {
                try refuse(
                    "attempts a body that cannot fail, so its rescue is a body"
                        + " no run reaches. What a rescue catches is what the"
                        + " body casts and calls, and this one casts and calls"
                        + " nothing that fails",
                    at: place,
                    when: ask
                )
            }

            let attempted = try await inspected(
                block: block,
                at: place,
                in: environment,
                with: context,
                ask: ask
            )
            let rescued = try await inspected(
                block: rescue,
                at: place.part(.rescue),
                in: caught(soaking: attempted.flow, failure: failure, in: environment, with: context),
                with: context,
                ask: ask
            )

            return Inspection(
                rewritten: ask.rewrites
                    ? .attempt(attempted.block, rescue: rescued.block, failure: failure)
                    : expression,
                calls: attempted.calls + rescued.calls,
                reading: join(attempted.reading, rescued.reading),
                flow: either(
                    absorbed(attempted.flow),
                    or: absorbed(rescued.flow)
                )
            )
        }
    }

    // A call through a contract. Nothing here names a declaration: what the
    // contract asked is the whole of the judgment, and which body runs is
    // decided at the run by the name the receiver wears.
    private func inspected(
        contract asked: ContractProcedure,
        call: Call,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> Inspection {
        guard let written = call.receiver else {
            throw BuildError(
                "sends '\(call.selector)' with nothing in front of it."
                    + " A contract's procedure is answered about the value it is"
                    + " sent to, so there is nothing here to answer it",
                at: place
            )
        }

        let receiver = try await inspected(
            written,
            at: place.part(.receiver),
            in: environment,
            with: context,
            ask: ask
        )

        switch context.loweredTypes.answering(contract: asked.contract, reading: receiver.reading) {
        case let .leansOn(types):
            for type in types {
                ask.fulfillment?.require(
                    Claim(type: type, contract: asked.contract),
                    at: place.part(.receiver)
                )
            }

        case .settled(true):
            break

        case .settled(false):
            throw BuildError(
                "sends '\(call.selector)' to \(receiver.reading.rendered(in: context.loweredTypes)),"
                    + " which does not answer every procedure '\(asked.contract)' asks",
                at: place.part(.receiver)
            )
        }

        var arguments: [Name: Expression] = [:]
        var calls = receiver.calls

        for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
            guard let parameter = asked.signature.parameters[name] else {
                throw BuildError(
                    "sends '\(call.selector)' with '\(name)', which"
                        + " '\(asked.contract)' does not name",
                    at: place.argument(name.spelling)
                )
            }

            let inner = try await inspected(
                argument,
                at: place.argument(name.spelling),
                in: environment,
                with: context,
                ask: ask
            )

            let declared = parameter.declared.lowered(in: context.loweredTypes)

            guard declared.accepts(inner.reading, in: context.loweredTypes) else {
                throw BuildError(
                    "hands \(inner.reading.rendered(in: context.loweredTypes)) where '\(asked.contract)'"
                        + " writes \(parameter.declared.rendered)",
                    at: place.argument(name.spelling)
                )
            }

            if let refusal = refusal(
                holding: inner.reading,
                to: declared,
                as: "hands",
                in: context.loweredTypes,
                fulfillment: ask.fulfillment,
                at: place.argument(name.spelling)
            ) {
                throw BuildError(refusal, at: place.argument(name.spelling))
            }

            arguments[name] = inner.rewritten
            calls += inner.calls
        }

        for (name, parameter) in asked.signature.parameters.sorted(by: { $0.key < $1.key })
        where call.arguments[name] == nil {
            guard
                parameter.default != nil
                    || parameter.declared.lowered(in: context.loweredTypes).declaresNull(in: context.loweredTypes)
            else {
                throw BuildError(
                    "sends '\(call.selector)' without '\(name)', which"
                        + " '\(asked.contract)' asks for",
                    at: place.part(.arguments)
                )
            }
        }

        return Inspection(
            rewritten: ask.rewrites
                ? .call(Call(receiver: receiver.rewritten, selector: call.selector, arguments: arguments))
                : .call(call),
            calls: calls,
            reading: asked.signature.returns?.lowered(in: context.loweredTypes) ?? .any
        )
    }

    // A block: its body, then the result in the environment the body left
    // visible. A result after a statement no run comes back from is judging's
    // to refuse. The reading ask answers `never` and moves on.
    private func inspected(
        block: Block,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> (block: Block, calls: [CallSite], reading: LoweredType, flow: Flow) {
        let body = try await inspected(
            block.body,
            at: place.part(.body),
            in: environment,
            with: context,
            ask: ask
        )

        // Where the result reads, or why it does not. A block's result sits
        // after its statements. It reads in the environment the body left, and
        // a body no run comes back from leaves it nothing to run, refused. The
        // one rule the type has: a loop's exit-answered result is the loop's
        // own to read, not this walk's.
        let tail: Inspection?
        let reading: LoweredType
        let flow: Flow

        if body.reading == .never {
            if block.result != nil {
                try refuse(
                    "never finishes before it, and nothing"
                        + " written after it would ever run",
                    at: place.part(.result),
                    when: ask
                )
            }

            tail = nil
            reading = .never
            flow = body.flow
        } else if let result = block.result {
            let read = try await inspected(
                result,
                at: place.part(.result),
                in: body.environment,
                with: context,
                ask: ask
            )

            tail = read
            reading = read.reading
            flow = sequenced(body.flow, then: read.flow)
        } else {
            tail = nil
            reading = .null
            flow = body.flow
        }

        // One assembly for every way through, so no way out can drop what
        // judging rewrote.
        return (
            ask.rewrites
                ? Block(body: body.body, result: tail?.rewritten ?? block.result)
                : block,
            body.calls + (tail?.calls ?? []),
            reading,
            flow
        )
    }

    // The statement walk's answers, named once. The fixpoint hands one back, so
    // its asker and the walk cannot disagree about the type.
    private typealias BodyWalk = (
        body: [Statement],
        calls: [CallSite],
        environment: [Name: Binding],
        reading: LoweredType,
        flow: Flow,
        locals: Set<Name>
    )

    // A body read in order: the environment its statements leave behind,
    // `never` where one of them ends every way through, and its outward writes.
    // Each statement's own binding included, except the names the body declared
    // itself, which die with it. Only the box a `set` writes outlives the
    // block. The one statement of the sequence rule, whichever ask is walking.
    private func inspected(
        _ body: [Statement],
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> BodyWalk {
        var environment = environment
        var locals: Set<Name> = []
        var flowed = Flow()
        var rewritten: [Statement] = []
        var calls: [CallSite] = []

        for (position, statement) in body.enumerated() {
            let here = place.statement(statement, at: position)

            let inner = try await inspected(
                statement.expression,
                at: here,
                in: environment,
                with: context,
                ask: ask
            )

            rewritten.append(
                Statement(binding: statement.binding, expression: inner.rewritten)
            )
            calls += inner.calls

            // A write outlives the block it was written in, so a name written
            // anywhere inside this statement may hold something else by the
            // time the next one reads it, and bubbles outward, except through
            // the names this body declared itself.
            apply(inner.flow, to: &environment)

            for (name, write) in inner.flow.written where !locals.contains(name) {
                flowed.written[name] = merged(flowed.written[name], with: write)
            }

            for (name, type) in inner.flow.escaped where !locals.contains(name) {
                flowed.escaped[name] = join(flowed.escaped[name], type)
            }

            flowed.answered = joined(flowed.answered, inner.flow.answered)

            // A statement no run comes back from ends the ways through this
            // body. What was written on the way to it leaves with it. One
            // predicate says so, and everything the fact decides reads it here:
            // judging refuses a name on the statement (a binding that cannot
            // happen) and anything written after it, which would never run.
            // What the syntactic leaves get at reading, a call gets here, where
            // the signature is known.
            if inner.flow.leaves || inner.reading == .never {
                if statement.binding != nil {
                    try refuseNeverBinding(at: here, when: ask)
                }

                if position != body.count - 1 {
                    // The leaving statement, not what follows it: what an
                    // author has to change is the one that ends the body, and
                    // the load says the same thing from the same place.
                    try refuse(
                        "every way through this statement leaves, and what"
                            + " follows it here would never run",
                        at: here,
                        when: ask
                    )
                }

                // Judging refused anything after this statement above, so
                // what is handed back is exactly what was walked.
                return (
                    ask.rewrites ? rewritten : body,
                    calls,
                    environment,
                    .never,
                    leaving(flowed),
                    locals
                )
            }

            if statement.binding?.declared != nil, statement.expression.namesItsOwn {
                try refuse(Expression.declarationOnABoundName, at: here, when: ask)
            }

            switch statement.binding {
            // A name that says what it holds holds that. One that says
            // nothing holds what the link worked out from what it was given.
            case let .constant(id, declared)?:
                locals.insert(id)
                environment[id] = .fixed(try held(inner.reading, declaredAs: declared, at: here, with: context, when: ask))

            case let .variable(id, declared)?:
                locals.insert(id)

                let holds = try held(inner.reading, declaredAs: declared, at: here, with: context, when: ask)
                environment[id] = declared == nil ? .assigned(holds) : .declared(holds)

            // A write to a whole variable retypes it, the way a declaration
            // did, unless the box's type is fixed elsewhere, in which case what
            // is written has to fit. A write through a path is judged against
            // the type the path reaches, and leaves the variable's type as it
            // was.
            case let .assignment(path)?:
                guard let id = path.head else { break }

                switch environment[id] {
                case let .declared(fixed)?:
                    try refuseUnfit(
                        inner.reading,
                        writtenTo: path,
                        holding: fixed,
                        in: environment,
                        with: context,
                        at: here,
                        when: ask
                    )

                case .assigned?:
                    if path.count == 1 {
                        environment[id] = .assigned(inner.reading)

                        if !locals.contains(id) {
                            flowed.written[id] = merged(flowed.written[id], with: (inner.reading, true))
                        }
                    } else {
                        try refuseUnfit(
                            inner.reading,
                            writtenTo: path,
                            holding: nil,
                            in: environment,
                            with: context,
                            at: here,
                            when: ask
                        )

                        if !locals.contains(id), let current = environment[id]?.type {
                            flowed.written[id] = merged(flowed.written[id], with: (current, true))
                        }
                    }

                case .fixed?, nil:
                    try refuse(
                        "writes '\(id)', which is not a variable here",
                        at: here,
                        when: ask
                    )
                }

            // A nameless statement writes no name for a later reading to
            // find.
            case nil:
                break
            }
        }

        return (ask.rewrites ? rewritten : body, calls, environment, .null, flowed, locals)
    }

    // What never finishes binds nothing, so a name on it promises a binding
    // that cannot happen. Asked exactly where the sequence rule finds a
    // statement that ends the body, so the two facts cannot part. The reader
    // catches the types it can see, and the link catches the procedures only it can
    // see. One rule, two stages.
    private func refuseNeverBinding(at place: Place, when ask: Ask) throws {
        try refuse(
            "never finishes,"
                + " so it binds nothing and takes no name",
            at: place,
            when: ask
        )
    }

    // A way out took this flow with it: what it wrote is not the body's to hand
    // on (no run comes back) but it is not gone either, because the writes are
    // in the boxes and a loop or an attempt may absorb the leave. They move
    // aside as escaped, indefinite because how far the way got is the run's
    // fact, and a flow that leaves hands nothing on plainly.
    private func leaving(_ flowed: Flow) -> Flow {
        var left = flowed

        left.leaves = true

        for (name, write) in left.written {
            left.escaped[name] = join(left.escaped[name], write.type)
        }

        left.written = [:]

        return left
    }

    // The construct the ways out stop at. A `break` ends only its loop and the
    // flow after it goes on, so what escaped on the way is back in play, and
    // nothing a construct absorbed is certain: the round may not have run, the
    // body may have stopped anywhere, so absorbing is unconfirming, in this one
    // sentence rather than at every caller. A leave that reaches further (a
    // `return`) is over-counted here, which only widens a join; reading the
    // reach would narrow it, and nothing unsound rides on not doing so.
    private func absorbed(_ flowed: Flow) -> Flow {
        var stopped = indefinite(flowed)

        stopped.leaves = false

        for (name, type) in stopped.escaped {
            stopped.written[name] = merged(stopped.written[name], with: (type, false))
        }

        stopped.escaped = [:]

        return stopped
    }

    // One thing ran after another: each later write lands by the one landing
    // rule (a definite one wins the name, an indefinite one joins) what escaped
    // keeps riding for the construct that absorbs it, and a sequence whose tail
    // leaves leaves, everything written on the way going with it.
    private func sequenced(_ first: Flow, then second: Flow) -> Flow {
        guard !first.leaves else { return first }

        var flowed = first

        for (name, later) in second.written {
            flowed.written[name] = merged(flowed.written[name], with: later)
        }

        for (name, type) in second.escaped {
            flowed.escaped[name] = join(flowed.escaped[name], type)
        }

        flowed.answered = joined(flowed.answered, second.answered)

        return second.leaves ? leaving(flowed) : flowed
    }

    // One of two ways ran. A name both wrote holds either; a name one wrote may
    // not have been written at all, so nothing about it is definite. A way that
    // leaves hands on nothing (the ways that finish are the only ways a reading
    // after can stand on) but what it wrote rides along as escaped, for the
    // construct that absorbs the leave.
    private func either(_ taken: Flow, or declined: Flow) -> Flow {
        var flowed = Flow()

        for side in [taken.escaped, declined.escaped] {
            for (name, type) in side {
                flowed.escaped[name] = join(flowed.escaped[name], type)
            }
        }

        flowed.answered = joined(taken.answered, declined.answered)

        switch (taken.leaves, declined.leaves) {
        // A leaving flow holds its writes as escaped alone, gathered above.
        case (true, true):
            flowed.leaves = true

        case (true, false):
            flowed.written = declined.written

        case (false, true):
            flowed.written = taken.written

        case (false, false):
            for name in Set(taken.written.keys).union(declined.written.keys) {
                switch (taken.written[name], declined.written[name]) {
                case let (mine?, theirs?):
                    flowed.written[name] = (
                        join(mine.type, theirs.type),
                        mine.definite && theirs.definite
                    )

                case let (mine?, nil):
                    flowed.written[name] = (mine.type, false)

                case let (nil, theirs?):
                    flowed.written[name] = (theirs.type, false)

                case (nil, nil):
                    break
                }
            }
        }

        return flowed
    }

    // The writes of a body that may not have run, or not run to its end.
    private func indefinite(_ flowed: Flow) -> Flow {
        var indefinite = flowed

        indefinite.written = flowed.written.mapValues { write in (write.type, false) }

        return indefinite
    }

    // The environment a loop's insides read: the enclosing names plus the
    // round. One maker, because the fixpoint and its asker both read it.
    private func rounded(
        _ environment: [Name: Binding],
        as round: Name
    ) -> [Name: Binding] {
        environment.merging([round: .fixed(Self.roundType)]) { _, new in new }
    }

    // The environment a rescue stands in: the entry, soaked with what the body
    // may have written before it failed (no write certain, none ruled out) plus
    // the failure under its name.
    private func caught(
        soaking flow: Flow,
        failure: Name,
        in environment: [Name: Binding],
        with context: TypingContext
    ) -> [Name: Binding] {
        var caught = environment

        apply(absorbed(flow), to: &caught)
        caught[failure] = .fixed(FailurePayload.declared.lowered(in: context.loweredTypes))

        return caught
    }

    // A round's body, read in the environment its own earlier rounds may have
    // written. The caller hands the one reader its rounds have, the body's flow
    // joins into the entry environment, and the body is re-read until the
    // reading stops moving. The reader reads with the reading ask, because a
    // refusal mid-climb would be a refusal of an environment no run ever stands
    // in. A body that writes nothing outward settles on the first look; a chain
    // of writes settles one link per look, so the bound is the chain's own
    // size: the names the body writes, times the few steps the join ladder has.
    // Past it the readings are not climbing (they are cycling) and everything
    // the body writes falls to `any`, over-wide and never wrong; the judging
    // ask answers that state out loud, where it can refuse.
    private func settled<Round>(
        from entry: [Name: Binding],
        read: ([Name: Binding]) async throws -> (round: Round, flow: Flow)
    ) async rethrows -> (environment: [Name: Binding], last: Round, converged: Bool) {
        var seeded = entry
        var (last, flow) = try await read(seeded)
        var steps = 0

        while true {
            var next = entry

            apply(absorbed(flow), to: &next)

            guard next != seeded else { return (seeded, last, true) }
            guard steps < 3 * max(1, absorbed(flow).written.count) + 1 else { break }

            steps += 1
            seeded = next
            (last, flow) = try await read(seeded)
        }

        var widened = entry

        for name in absorbed(flow).written.keys {
            widened[name] = .assigned(.any)
        }

        // One more look in the widened environment, so what is handed back
        // was read where the caller will stand.
        let (settled, _) = try await read(widened)

        return (widened, settled, false)
    }

    // What a settled value reads as. Internal, because a constant is a value
    // whose type seeds the environment its readers are judged in.
    func type(of value: Value, in table: LoweredTypeTable) -> LoweredType {
        switch value {
        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case .bytes:
            return .array(.byteElement)

        // A procedure that already exists as a value says nothing about itself
        // that this walk can read.
        case .procedure:
            return .procedure(parameters: nil, returns: nil, constness: .unstated, isolation: .unstated)

        case let .array(elements):
            return .array(
                elements
                    .map { element in type(of: element, in: table) }
                    .reduce(nil) { joined, next in join(joined, next) } ?? .any
            )

        // A record under a name reads as that name; the type is the
        // declaration's, and the name is what the value fits. A document's
        // type names its fields by Swift's equality, so two spellings the
        // value keeps apart are one field here, the first by bytes.
        case let .record(record):
            return record.name.flatMap { name in table.row(named: name).map(LoweredType.named) }
                ?? .record(
                    Dictionary(
                        zip(record.names, record.values).map { name, value in (name, type(of: value, in: table)) }
                    ) { first, _ in first }
                )

        case let .dictionary(dictionary):
            return .record(
                Dictionary(
                    dictionary.entries.map { entry in (entry.name, type(of: entry.value, in: table)) }
                ) { first, _ in first }
            )
        }
    }

    // Two readings of one slot. Where they disagree the slot holds neither,
    // which is what `any` says. A join that guessed would be a refusal an
    // author cannot act on.
    //
    // A reading that leaves is not one of the two. It contributes no value, so
    // it cannot disagree with the reading that stays, and the slot holds what
    // the other one said.
    private func join(_ left: LoweredType?, _ right: LoweredType) -> LoweredType {
        guard let left else { return right }
        guard left != .never else { return right }
        guard right != .never else { return left }

        // Null beside a value is absence beside presence, and a slot that may
        // hold either is what `T?` says. A nullable side joins by what it
        // holds, so the one fact (null may be here) is said once.
        if left == .null { return nullableReading(of: right) }
        if right == .null { return nullableReading(of: left) }

        if case let .nullable(mine) = left {
            return nullableReading(of: join(mine, right))
        }

        if case let .nullable(theirs) = right {
            return nullableReading(of: join(left, theirs))
        }

        // Two procedures join to a procedure rather than to `any`, keeping the
        // constness both of them have. Collapsing here would let one body that
        // runs, in a list of them, pass a slot that asked for none, because
        // `any` is accepted everywhere.
        if
            case let .procedure(mine, myAnswer, wanted, wantedIsolation) = left,
            case let .procedure(theirs, theirAnswer, offered, offeredIsolation) = right
        {
            let agreed = left.sameProcedure(as: right)

            return .procedure(
                parameters: agreed ? mine : nil,
                returns: agreed ? myAnswer : nil,
                constness: wanted == .const && offered == .const ? .const : .unstated,
                isolation: wantedIsolation == .isolated && offeredIsolation == .isolated ? .isolated : .unstated
            )
        }

        guard left != right else { return left }

        // Unequal spellings may still be one type: the equations (a range is an
        // int with a condition, bytes are `array<byte>`) are read through their
        // normal forms before the join gives up, and two arrays join by their
        // elements so the equation holds inside one.
        let mine = left.unrefined
        let theirs = right.unrefined

        if case let .array(myElement) = mine, case let .array(theirElement) = theirs {
            return .array(join(myElement, theirElement))
        }

        return mine == theirs ? mine : .any
    }
}

extension Builder {
    // Where a write lands, or why it lands nowhere.
    enum Writable {
        case reaches(LoweredType)
        case refused(String)
    }

    // MARK: - Internal
    // What a path write reaches, or why it may not. The head is a box; each
    // field on the way is one a declared type wrote `var`, or a field of a
    // type no declaration named; an element is written through its index. A
    // type that may be null is not written into, and neither is `any`.
    func writable(
        _ path: [PathSegment],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        writing fulfillment: Fulfillment?
    ) -> Writable {
        guard case let .key(head, _)? = path.first, let box = environment[head] else {
            return .refused("writes '\(path.rendered)', and its head is not a name here")
        }

        var current = box.type
        var walked: [PathSegment] = [.key(head)]

        for segment in path.dropFirst() {
            walked.append(segment)

            if segment.optional {
                return .refused(
                    "\(walked.rendered) writes through `\(segment.mark)`, and a write"
                        + " reads no absence. Write the whole, or write what is there"
                )
            }

            // Whether the container being entered is a declared type's, which
            // is asked of this segment alone: a record written inline under a
            // `var` field is nobody's declaration.
            var declared = false

            if case .named = current {
                declared = true
            }

            if case let .indexRef(inner, _) = segment {
                if case let .refused(reason) = indexReference(inner, in: environment, with: context, at: place, writing: fulfillment) {
                    return .refused(reason)
                }
            }

            current = context.resolve(current)

            switch (segment, current) {
            case let (.key(key, _), .record(fields)):
                guard let field = fields[key] else {
                    return .refused(
                        "\(walked.rendered) names '\(key)', which \(current.rendered(in: context.loweredTypes))"
                            + " does not declare"
                    )
                }

                if declared, !field.isVariable {
                    return .refused(
                        "\(walked.rendered) writes through '\(key)', which the type"
                            + " declares without `var`. A field a path may write"
                            + " through is declared `var`"
                    )
                }

                current = field.fieldUnwrapped

            case let (.key, .dictionary(entry)):
                current = entry

            case let (.index, .array(element)), let (.indexRef, .array(element)):
                current = element

            case (.key, .any), (.index, .any), (.indexRef, .any):
                return .refused(
                    "\(walked.rendered) writes into \(current.rendered(in: context.loweredTypes)), which"
                        + " declares nothing. A type is written by naming it"
                )

            case (.key, .nullable), (.index, .nullable), (.indexRef, .nullable):
                return .refused(
                    "\(walked.rendered) writes into \(current.rendered(in: context.loweredTypes)), which may"
                        + " be null. Write the whole first"
                )

            case (.key, _):
                return .refused(
                    "\(walked.rendered) writes a field into \(current.rendered(in: context.loweredTypes)),"
                        + " which has none"
                )

            case (.index, _), (.indexRef, _):
                return .refused(
                    "\(walked.rendered) writes an element into \(current.rendered(in: context.loweredTypes)),"
                        + " and only an array is written by position"
                )
            }
        }

        return .reaches(current)
    }

    // The rules a call handing variables in place is held to: the argument is
    // a path, the path's head is a variable here, and the path is one a write
    // may take. Two parameters handed paths under one head hold one box two
    // ways, and every write lands in it as it is made, so nothing here keeps
    // them apart.
    private func handedInPlace(
        by call: Call,
        to signature: Signature,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws {
        guard case .judging = ask else { return }

        for (name, parameter) in signature.parameters.sorted(by: { $0.key < $1.key })
        where parameter.declared.isInout {
            guard let argument = call.handed(name, to: signature) else { continue }

            let at = name == signature.receiver
                ? place.part(.receiver)
                : place.argument(name.spelling)

            guard case let .reference(path) = argument, let head = path.head else {
                try refuse(
                    "hands '\(name)' in place, and what is handed in place is a"
                        + " variable's path. This argument is not one",
                    at: at,
                    when: ask
                )
                continue
            }

            guard environment[head]?.isBox == true else {
                try refuse(
                    "hands '\(head)' in place, which is a fixed name here. A"
                        + " variable is handed in place",
                    at: at,
                    when: ask
                )
                continue
            }

            if case let .refused(reason) = writable(path, in: environment, with: context, at: at, writing: ask.fulfillment) {
                try refuse("hands '\(name)' in place, and \(reason)", at: at, when: ask)
            }
        }
    }

    // What a name holds: what it declared, held against what it was given, or
    // what the link worked out where it declared nothing.
    private func held(
        _ given: LoweredType,
        declaredAs written: TypeExpression?,
        at place: Place,
        with context: TypingContext,
        when ask: Ask
    ) throws -> LoweredType {
        guard let declared = written?.lowered(in: context.loweredTypes) else { return given }

        guard declared.accepts(given, in: context.loweredTypes) else {
            try refuse(
                "holds \(declared.rendered(in: context.loweredTypes)), and what it was given is"
                    + " \(given.rendered(in: context.loweredTypes))",
                at: place,
                when: ask
            )

            // The reading ask has no refusal to throw, and what the name holds
            // is what it declared either way. Handing back what it was given
            // would leave the two walks reading one name as two types.
            return declared
        }

        if let refusal = refusal(
            holding: given,
            to: declared,
            as: "holds",
            in: context.loweredTypes,
            fulfillment: ask.fulfillment,
            at: place
        ) {
            try refuse(refusal, at: place, when: ask)
        }

        return declared
    }

    private func refuseUnfit(
        _ written: LoweredType,
        writtenTo path: [PathSegment],
        holding fixed: LoweredType?,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws {
        let slot: LoweredType

        if path.count == 1, let fixed {
            slot = fixed
        } else {
            switch writable(path, in: environment, with: context, at: place, writing: ask.fulfillment) {
            case let .refused(reason):
                try refuse(reason, at: place, when: ask)
                return

            case let .reaches(reached):
                slot = reached
            }
        }

        guard slot.accepts(written, in: context.loweredTypes) else {
            try refuse(
                "writes '\(path.rendered)' as \(written.rendered(in: context.loweredTypes)), and it holds"
                    + " \(slot.rendered(in: context.loweredTypes))",
                at: place,
                when: ask
            )
            return
        }

        if let refusal = refusal(
            holding: written,
            to: slot,
            as: "writes '\(path.rendered)' as",
            in: context.loweredTypes,
            fulfillment: ask.fulfillment,
            at: place
        ) {
            try refuse(refusal, at: place, when: ask)
        }
    }
}
