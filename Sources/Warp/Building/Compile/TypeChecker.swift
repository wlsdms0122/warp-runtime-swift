//
//  TypeChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What each name in a body holds, worked out by reading the body in order.
//
// An author binds a call to a name and passes the name, so a declared `returns`
// only reaches the next call site if the build knows what that name holds. This
// is what knows: `said = call counts` followed by `wants(said)` is two
// declarations disagreeing, and both are text.
//
// Nothing here is required to say anything: what cannot be read is `Any`,
// which stands where `Any` is declared and anywhere else once a cast says
// what it is. A wrong answer would be a refusal an author cannot act on, so
// the walk answers only where the text says so.
//
// A dot on `Any` is held the same way: a dot needs a type to be judged
// against, so it refuses rather than deferring to the run. The author names
// the type with `as`, and the walk goes on from there.
//
// A path reads a name and nothing else, so every segment a document writes
// stays what it was written as. What each one lands on is judged here against
// the type the walk reached, and a dot on a type that declares no such field
// is refused rather than left for the run.
struct TypeChecker {
    // What a call put in a generic declaration's type parameters, read once:
    // a parameter read two ways is refused rather than folded, a bounded one
    // is judged against its bounds, and the declaration comes back with
    // the readings filled.
    private enum Instantiation {
        case fits(slots: [Slot], returns: LoweredType?)
        case refusal(String)
    }

    // Where a path walk ended: what the whole of the path holds, or the
    // refusal. The segments stand as written either way.
    private enum PathReading {
        case reads(LoweredType)
        case refused(String)
    }

    // The two asks the one walk answers. Judging is the compile's own pass
    // (every dot judged, every constant-headed path folded, every call
    // gathered, every refusal thrown) and it happens once per site. Probing
    // answers the type and flow questions alone and refuses nothing (what
    // cannot be read is `Any`) because its askers read a body out of place or
    // more than once: an operand typed where it stands, a round re-read until
    // its writes settle, where a refusal would be transient or repeated. One
    // walk under two asks, so the rules cannot drift a copy at a time, and so a
    // body is read once, where a walk per question would compound arm by arm
    // into an exponential reading of nothing new.
    private enum Ask {
        // Judging carries what folds a constant-headed path, where there is
        // one, where it writes down the pairs its calls lean on, and what the
        // body being judged declares it answers, which a literal it answers
        // with is written into. Probing writes nothing.
        case judging(folding: Folding?, writing: Fulfillment, answering: LoweredType?)
        case probing

        // MARK: - Property
        // Whether this ask keeps what the walk rebuilds. Probing reads a body
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

        // What a `return` in the body being judged hands its answer to.
        var answer: LoweredType? {
            guard case let .judging(_, _, answering) = self else { return nil }

            return answering
        }

        // MARK: - Initializer
        // MARK: - Public
        // The same ask for a body that declares it answers `type`.
        func answering(_ type: LoweredType?) -> Ask {
            guard case let .judging(folding, writing, _) = self else { return self }

            return .judging(folding: folding, writing: writing, answering: type)
        }

        // MARK: - Private
    }

    // One walk's answers: the expression as judging leaves it (constant-headed
    // paths folded, a closure literal's signature bounded), the sends gathered
    // on the way, what it judged of each call of a value and each closure
    // literal in it by where each stands, what the whole of it holds, and what
    // it wrote to the names around it. The probing ask hands the expression
    // back as written and gathers nothing.
    private struct Inspection {
        // MARK: - Property
        var rewritten: Expression
        var calls: [CallSite] = []
        var judgements = JudgementTable()
        var reading: LoweredType
        var flow = Flow()

        // What a list or record literal holds where it is written into a
        // slot, part by part, where its reading, joined across the parts, does
        // not say. A block or a loop holds what its result holds, and an
        // attempt what each of its two ways answers.
        var literalShape: LiteralShape?

        // What the expression holds where it is written into a slot.
        var written: LiteralShape {
            LiteralShape(literalShape, reading: reading)
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // The statement walk's answers, named once. The fixpoint hands one back, so
    // its asker and the walk cannot disagree about the type.
    private typealias BodyWalk = (
        body: Body,
        calls: [CallSite],
        judgements: JudgementTable,
        environment: [Name: Binding],
        reading: LoweredType,
        flow: Flow,
        locals: Set<Name>
    )

    // Where a write lands, or why it lands nowhere.
    private enum Writable {
        case reaches(LoweredType)
        case refused(String)
    }

    // A declaration whose answer nobody wrote, with what it takes to read one
    // off the body: the body itself, the names in scope before its first
    // statement, and which other unwritten answers its own may come from.
    struct Unsaid {
        // MARK: - Property
        // The declaration itself, rather than the two things this walk asks of
        // it. What it is called across the link and where it is written in the
        // document are both the symbol's to say, and copying either out here
        // would be a second place the rule for it lives.
        let symbol: Symbol

        let block: Block
        let environment: [Name: Binding]
        let sends: Set<Name>

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    private static let roundType = LoweredType.record(.round)

    // MARK: - Initializer
    // MARK: - Public
    // A block with every dot judged and every call gathered, each site carrying
    // what was in scope where it was written. Statements are read in order
    // because that is what a body means. A name holds what the statement before
    // it bound.
    func resolvedSites(
        in block: Block,
        at place: Place,
        in environment: [Name: Binding],
        declaring selector: Name,
        answering returns: TypeExpression?,
        with context: TypingContext,
        folding: Folding?,
        writing fulfillment: Fulfillment
    ) async throws -> (block: Block, calls: [CallSite], judgements: JudgementTable) {
        let promised = returns?.lowered(in: context.loweredTypes, bounds: context.bounds)

        // A closure literal the body answers, at any depth, is completed by
        // the type the declaration answers.
        let inner = try await inspected(
            block: promised.map { promised in promised.completing(block, in: context.loweredTypes) } ?? block,
            at: place,
            in: environment,
            with: context,
            ask: .judging(folding: folding, writing: fulfillment, answering: promised)
        )

        try held(
            written: LiteralShape(inner.literalShape, reading: inner.reading),
            answered: inner.flow.answered,
            to: returns,
            bounds: context.bounds,
            result: inner.block.result,
            at: place,
            in: context.loweredTypes,
            fulfillment: fulfillment
        )

        var judgements = inner.judgements

        if let promised {
            judgements.record(names: promised.naming(inner.block, at: place, in: context.loweredTypes))
        }

        return (promised.map { promised in promised.written(inner.block, in: context.loweredTypes) } ?? inner.block, inner.calls, judgements)
    }

    // The expression form, with what it was judged to hold. A constant's body
    // is one rather than a block.
    func resolvedSites(
        in expression: Expression,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        folding: Folding?,
        writing fulfillment: Fulfillment
    ) async throws -> (Expression, [CallSite], JudgementTable, LiteralShape) {
        let inner = try await inspected(
            expression,
            naming: nil,
            at: place,
            in: environment,
            with: context,
            ask: .judging(folding: folding, writing: fulfillment, answering: nil)
        )

        return (inner.rewritten, inner.calls, inner.judgements, LiteralShape(inner.literalShape, reading: inner.reading))
    }

    // A constant and a variable's start settle at the build, so what each is
    // written from is read rather than run. The same gate an operand passes:
    // an operand, a constant and a variable's start are where the build reads
    // an expression instead of running it.
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
            when: .judging(folding: nil, writing: fulfillment, answering: nil)
        )
    }

    // What a declaration answers when nobody wrote it down, read off its body.
    // Not into the declaration: what the author wrote is what the image
    // carries and what the boundary checks, and an answer worked out here is
    // the build's own reading rather than anybody's promise. It reaches
    // exactly as far as the readings do.
    //
    // A body's answer may be another body's, so the order is the call graph's. Each
    // declaration read after everything its answer could come from. Bodies that
    // reach one another's answers in a cycle, a recursive one included, are read
    // as `Any`: an answer worked out from itself is not one the text states, and a
    // guess there would be a refusal an author cannot act on. Writing `returns` is
    // what says more, and it removes the cycle by saying it.
    //
    // Every unwritten answer, read off its body, one at a time in the order the
    // call graph allows. Each handed back as it is worked out, and the context
    // asked for again, so the next body is read against it.
    //
    // Handed back rather than returned in a heap: the tables a context is made
    // of are the build's, one answer changes one entry in each, and rebuilding
    // them per declaration is the whole graph copied once per node.
    func answers(
        of unsaid: [Unsaid],
        reading context: () -> TypingContext,
        recording: (Name, LoweredType) -> Void
    ) async {
        let declared = Dictionary(
            unsaid.map { one in (one.symbol.declared, one) },
            uniquingKeysWith: { first, _ in first }
        )

        let edges = Dictionary(
            unsaid.map { one in (one.symbol.declared, one.sends.sorted()) },
            uniquingKeysWith: { first, _ in first }
        )

        for component in StronglyConnected(among: edges).components() {
            // One declaration that does not reach its own answer is the only
            // type a body can be read for. Everything else is a cycle, and
            // a cycle says nothing.
            guard
                component.count == 1,
                let only = component.first.flatMap({ name in declared[name] }),
                !only.sends.contains(only.symbol.declared)
            else {
                for name in component { recording(name, .any) }

                continue
            }

            // A refusal is the judging pass's to state, in its own terms and
            // at its own place, so what this pass cannot read it treats as
            // unread.
            let read = try? await reading(
                from: only.block,
                at: only.symbol.place,
                in: only.environment,
                with: context().bounding(only.symbol.procedure.signature.bounds)
            )

            // A reading naming a type parameter is handed on as it is. What a
            // parameter means is settled at the call, by the same filling a
            // declared `returns: some T` goes through, so a body answering its
            // own parameter answers what the caller put there, and a body
            // answering a type only it could name (what a walk *through* a
            // parameter reaches, named for the path that reached it) fills with
            // nothing, which is `Any`. One rule, and the useful half comes for
            // free.
            recording(only.symbol.declared, read ?? .any)
        }
    }

    // Which declarations a body may read an answer from: every selector it
    // sends. Read off the one walk `Expression` owns.
    func sent(in block: Block) -> Set<Name> {
        block.subexpressions.reduce(into: Set<Name>()) { sent, expression in
            guard case let .call(call) = expression else { return }

            sent.insert(call.selector)
        }
    }

    // The one gate every gathered call passes, wherever its body sits, and
    // whether its selector names a declaration or a contract's procedure. The
    // call is judged against the signature its selector names.
    func checked(_ calls: [CallSite], in context: TypingContext, writing fulfillment: Fulfillment) throws {
        for call in calls {
            guard let signature = context.signature(of: call.call.selector) else {
                throw BuildError.unjudged(
                    "a call to '\(call.call.selector)', which names no declaration",
                    at: call.place
                )
            }

            try check(call, against: signature, with: context, writing: fulfillment)
        }
    }

    // MARK: - Private
    // What a body hands its caller: the result it reads, and every `return`
    // that carried something out. The two ways a procedure answers, joined.
    // Read rather than judged, because this is asked of a body the walk may
    // read again, and a refusal here would be one the judging pass is about to
    // state in its own place.
    private func reading(
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
            ask: .probing
        )

        return walked.flow.answer(resulting: walked.reading)
    }

    // One answer, held to the `returns`. The refusal stands where the author
    // can act on it: at the `result` when one is written, at the `returns`
    // when the body answers nothing at all, and at a `return` for what it
    // carries.
    private func held(
        _ written: LiteralShape,
        to returns: TypeExpression?,
        bounds: [Name: Set<Name>],
        at place: Place,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment
    ) throws {
        guard let returns else { return }

        let promised = returns.lowered(in: table, bounds: bounds)

        guard written.isHeld(by: promised, inPlace: false, in: table) else {
            throw BuildError(
                "answers \(written.rendered(in: table)), and its"
                    + " declaration promises \(promised.rendered(in: table))",
                at: place
            )
        }

        // A composition the declaration promises holds the answer to its
        // bounds the way a slot holds what arrives, wherever in the promise
        // it stands.
        if let refusal = refusal(
            writing: written,
            to: promised,
            as: "the answer holds",
            in: table,
            fulfillment: fulfillment,
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }
    }

    // Why what is written into a slot is provably outside it, part by part
    // along `everyPart(along:)`, or nothing.
    private func refusal(
        writing written: LiteralShape,
        to declared: LoweredType,
        as label: String,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment,
        at place: Place
    ) -> String? {
        var found: String?

        _ = written.everyPart(along: declared, inPlace: false, in: table) { slot, part, _ in
            found = refusal(holding: part.folded, to: slot, as: label, in: table, fulfillment: fulfillment, at: place)

            return found == nil
        }

        return found
    }

    // Why what arrived is provably outside what a declaration holds it to,
    // wherever in the declaration a composition stands, or nothing. What
    // leans on a claim this table cannot settle is written down for the
    // link to settle.
    private func refusal(
        holding given: LoweredType,
        to declared: LoweredType,
        as label: String,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment,
        at place: Place
    ) -> String? {
        var unread = Substitution()
        var untaken = Substitution()
        var holding: [Substitution.Held] = []

        declared.binding(against: given, into: &unread, taking: &untaken, holding: &holding, in: table)

        for held in holding {
            for contract in held.bounds {
                if let refusal = refusal(
                    of: held.reading,
                    answering: contract,
                    orNull: held.orNull,
                    as: label,
                    in: table,
                    fulfillment: fulfillment,
                    at: place
                ) {
                    return refusal
                }
            }
        }

        return nil
    }

    // Why a reading provably does not answer a contract a bound names, or
    // nothing where it is not. A contract asks a set of procedures the
    // reading's own type answers.
    private func refusal(
        of reading: LoweredType,
        answering name: Name,
        orNull: Bool,
        as label: String,
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment,
        at place: Place
    ) -> String? {
        switch loweredTypes.answering(contract: name, reading: reading, orNull: orNull) {
        // What leans on a claim is written down for the link to settle.
        case let .leansOn(types):
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
    }

    // Whether a write fits the slot it lands in, in the box `binding` holds.
    // A body declares no type parameter of its own, so a declared box whose
    // slot names one is a parameter handed in place.
    private func fits(
        _ written: LiteralShape,
        into slot: LoweredType,
        of binding: Binding?,
        in loweredTypes: LoweredTypeTable
    ) -> Bool {
        guard case .declared? = binding?.holding else { return written.isHeld(by: slot, inPlace: false, in: loweredTypes) }

        return written.isHeld(by: slot, inPlace: true, in: loweredTypes)
    }

    // The one bounds judgement a call is held to, over the whole signature.
    // Answers the refusal, or nil where every bounded parameter's readings
    // answer each of its bounds. That a named bound is declared is the
    // declaration's own fact, held where it is declared.
    private func boundsRefusal(
        bounds: [Name: Set<Name>],
        substitution: Substitution,
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment,
        at place: Place
    ) -> String? {
        for (parameter, names) in bounds.sorted(by: { $0.key < $1.key }) {
            for reading in substitution.everyReading(of: parameter) {
                for name in names.sorted() {
                    if let refusal = refusal(
                        of: reading,
                        answering: name,
                        orNull: false,
                        as: "'\(parameter)' is read as",
                        in: loweredTypes,
                        fulfillment: fulfillment,
                        at: place
                    ) {
                        return refusal
                    }
                }
            }
        }

        return nil
    }

    private func instantiated(
        _ declared: Signature,
        over slots: [Slot],
        answering: LoweredType?,
        readings sent: [LoweredType],
        shaped shapes: [Int: LiteralShape],
        in loweredTypes: LoweredTypeTable,
        fulfillment: Fulfillment,
        at place: Place
    ) -> Instantiation {
        // A declaration with nothing to fill is read as the build lowered it.
        // Lowering it again per call site is the same answer paid for again,
        // and this is the site every call goes through.
        guard declared.isGeneric else { return .fits(slots: slots, returns: answering) }

        let substitution = substitution(over: slots, readings: sent, in: loweredTypes)

        guard substitution.disagreeing.isEmpty else {
            let named = substitution.disagreeing.keys.sorted().map { parameter in
                "'\(parameter)' is read as \(substitution.readings[parameter]?.rendered(in: loweredTypes) ?? "?")"
                    + " and as \(substitution.disagreeing[parameter]?.rendered(in: loweredTypes) ?? "?")"
            }

            return .refusal(named.joined(separator: ", "))
        }

        if let refusal = boundsRefusal(
            bounds: declared.bounds,
            substitution: substitution,
            in: loweredTypes,
            fulfillment: fulfillment,
            at: place
        ) {
            return .refusal(refusal)
        }

        if let refusal = severalTypesRefusal(over: slots, substitution: substitution, in: loweredTypes) {
            return .refusal(refusal)
        }

        // A list or record literal handed where a bounded parameter stands is
        // held to the bounds part by part, as one written into a slot
        // declaring them is: its join may answer them while a part does not.
        // Only what stands at such a parameter is asked here; `check` judges
        // the rest against what filled it. Each part is asked as the call
        // hands it on, a whole literal the filled slot reads as a fraction
        // being that fraction.
        for (position, written) in shapes.sorted(by: { $0.key < $1.key }) where slots.indices.contains(position) {
            let slot = slots[position]
            let bounded = slot.type.boundedAlone

            guard bounded != .any else { continue }

            let shape = written.written(into: slot.type.filling(substitution.readings), in: loweredTypes)

            guard shape.isHeld(by: bounded, inPlace: false, in: loweredTypes) else {
                return .refusal(
                    "'\(slot.name)' holds \(shape.rendered(in: loweredTypes))"
                        + " where \(slot.type.rendered(in: loweredTypes)) is declared"
                )
            }

            if let refusal = refusal(
                writing: shape,
                to: bounded,
                as: "'\(slot.name)' holds",
                in: loweredTypes,
                fulfillment: fulfillment,
                at: place
            ) {
                return .refusal(refusal)
            }
        }

        return .fits(
            slots: declared.lowered(in: loweredTypes, filling: substitution.readings),
            returns: answering?.filling(substitution.readings)
        )
    }

    // Why a value of more than one type fills a bounded parameter it cannot,
    // or nil where none does. A bounded parameter is one type wherever it
    // stands, and a value of a contract is of whichever type answers it, and
    // one of what may be null of the type or `Null`, so two of them, or one
    // inside a list or a record, are not known to be one type. Standing
    // alone at one position, the value is the one thing the parameter stands
    // for, and the call reads the parameter the way it read the value.
    private func severalTypesRefusal(
        over slots: [Slot],
        substitution: Substitution,
        in loweredTypes: LoweredTypeTable
    ) -> String? {
        for (parameter, bounds) in slots.reduce(into: [Name: [Name]](), { found, slot in
            found.merge(slot.type.boundedParameters) { first, _ in first }
        }).sorted(by: { $0.key < $1.key }) where !bounds.isEmpty {
            guard let valueOfSeveral = substitution.everyReading(of: parameter).first(where: { reading in
                switch reading {
                case let .composition(read):
                    return !read.isEmpty

                case .nullable:
                    return true

                default:
                    return false
                }
            }) else {
                continue
            }

            let standing = slots.filter { slot in slot.type.boundedParameters[parameter] != nil }

            if standing.count == 1, case let .parameter(alone, _) = standing[0].type.slotUnwrapped, alone == parameter {
                continue
            }

            let spelled = parameter == TypeSpelling.selfType ? "`Self`" : "`some \(parameter)`"

            return "'\(parameter)' is read as \(valueOfSeveral.rendered(in: loweredTypes)), a value of more than one"
                + " type, and \(spelled) is one type wherever it stands. A value of a contract or of what may"
                + " be null fills a bounded parameter only where the parameter stands alone at one position"
        }

        return nil
    }

    // What a call put in its callee's type parameters, read by holding each
    // declared parameter beside what was actually sent at its position. The
    // readings already in hand, so nothing is walked a second time for the
    // asking.
    private func substitution(
        over slots: [Slot],
        readings sent: [LoweredType],
        in loweredTypes: LoweredTypeTable
    ) -> Substitution {
        Substitution(filling: slots.map(\.type), against: sent, in: loweredTypes)
    }

    // Walking a path through types the way the resolver walks it through
    // values. Each dot is judged by the type the walk has reached: a type
    // with fields reads one, and a type without them has no name there to
    // read, which is refused. The segments stand as written.
    //
    // A field the type does not declare is refused, `?.` or not. The type
    // proved the absence, and a spelling that reads expected absence does not
    // overrule a proof. What may genuinely be absent at run (a `Dictionary`
    // entry, a nullable's null) is where `?.` speaks: the plain spelling is
    // refused there, and the optional one answers null and makes the whole
    // path's reading nullable.
    //
    // Three types stop the walk, and each stops it for its own reason. On
    // `Any` the walk **refuses**: nothing was declared, so there is nothing a
    // dot could be judged against, and a dot no declaration proves is what a
    // run would otherwise have to decide for itself. The type is named
    // instead, with `as`. On a type parameter the segments stand **as
    // written**: the type is declared, at the call rather than here, and what
    // the call filled in answers them. On `Never` nothing arrives to be read at
    // all, so there is nothing to judge and nothing to refuse.
    private func reading(
        of path: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        guard let head = path.head, let bound = environment[head] else {
            return asWritten(path, in: environment, with: context, at: place)
        }

        var current = bound.type

        var walked: Path = [.key(head)]

        // Whether an optional segment read past a possible absence. The one
        // thing that makes the whole path's answer nullable.
        var optional = false

        for (offset, segment) in path.segments.dropFirst().enumerated() {
            current = context.resolve(current)
            walked.append(segment)

            // This segment and the ones after it, as written. For the walks
            // that stop judging early.
            func rest() -> Path {
                Path(Array(path.segments.dropFirst(offset + 1)))
            }

            // Whether this segment's `?.` read past a possible absence. A
            // `?.` that read past nothing claims an absence the types rule
            // out, and a claim the text cannot keep is refused below the way
            // a needless `?` on a type spelling is.
            var unwrapped = false

            // What the dot lands on, settled: the walk-stopping types are
            // asked again after every unwrap, because what a `T?` holds is a
            // type like any other (`Any`, null, another name, another nullable)
            // and an unwrap that skipped the questions would judge on a type
            // nobody checked.
            settling: while true {
                // Three types stop a walk, and they stop it for three
                // different reasons, so they are asked separately, and each
                // says its own. A dot is judged against what a declaration
                // proves at this site: `Any` declares nothing and never will, a
                // type parameter's type is declared at the call, and `Never`
                // declares a value that does not arrive at all.

                // Nothing was declared here, so nothing about this value can
                // ever be proven, and a dot the build cannot judge is the one
                // thing a run would have to decide for itself. The author says
                // what they expect and the reading goes on from there; the
                // type is theirs to name, not the value's to supply. An index
                // says as much as a dot does (that a type is there to be read
                // into) so it refuses here too, and says so in its own terms.
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

                // A type parameter is declared at the call, so the segments
                // stand as written and the call's type answers them. The
                // reading is what the parameter's type reaches through them,
                // neither `Any` nor the parameter itself, so a body naming a
                // step on the way (`held = of.inner`, then `held.count`) reads
                // the same field.
                if let reached = current.reaching(rest()) {
                    switch asWritten(rest(), in: environment, with: context, at: place) {
                    case let .refused(reason):
                        return .refused(reason)

                    case .reads:
                        return .reads(reached)
                    }
                }

                // Nothing arrives to be read, so there is nothing to judge and
                // nothing to refuse. The segments stand as written and the walk
                // stops. That the reading is unreachable is the leaving rules'
                // fact, said where they are said.
                if current == .never {
                    switch asWritten(rest(), in: environment, with: context, at: place) {
                    case let .refused(reason):
                        return .refused(reason)

                    case .reads:
                        return .reads(.never)
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

                    switch asWritten(rest(), in: environment, with: context, at: place) {
                    case let .refused(reason):
                        return .refused(reason)

                    case .reads:
                        return .reads(.null)
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

            // What an index lands on, once the walk knows it is an array. An
            // element past the end is a defect at the run, not an absence, so `?[` says nothing
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
            case let (.indexRef(inner, _), .array(element)):
                if let refusal = indexReference(inner, in: environment, with: context, at: place) {
                    return .refused(refusal)
                }

                if let refused = indexed(element) { return refused }

            case let (.index, .array(element)):
                if let refused = indexed(element) { return refused }

            // A dictionary's names are data, so a key the run settles reads an
            // entry the way a written key does. Absence follows the mark, the
            // rule every entry reading shares.
            case let (.indexRef(inner, optionally), .dictionary(entry)):
                if let refusal = keyReference(inner, in: environment, with: context, at: place) {
                    return .refused(refusal)
                }

                if let refusal = needless(.entry) { return refusal }

                if optionally { optional = true }

                current = entry

            case (.index, _), (.indexRef, _):
                return .refused(
                    "\(walked.rendered) indexes into \(current.rendered(in: context.loweredTypes)),"
                        + " and an array is indexed by a position or a name the run settles,"
                        + " a dictionary by a name the run settles alone"
                )

            // A dictionary holds entries of one type under names that are
            // data, so which names are there is a run's fact. `?.` reads an
            // absent one as null, and the plain spelling refuses it at run. The
            // rule is asked here like everywhere else and always answers yes:
            // the mark has an absence to expect on an entry, unwrapped or not,
            // and that fact lives in the rule rather than in this landing.
            case let (.key, .dictionary(entry)):
                if let refusal = needless(.entry) { return refusal }

                if segment.optional { optional = true }

                current = entry

            // A dot on a record reads the field it declares. A field it does
            // not declare is a defect the text shows, refused here rather than
            // found at run, and so is a `?.` on one it does declare: the type
            // proves the field is there, so the spelling that expects absence
            // says nothing, unless it just read past the record's own null.
            case let (.key(key, _), .record(fields)):
                guard let field = fields[key] else {
                    return .refused(
                        "\(walked.rendered) names '\(key)',"
                            + " which \(current.rendered(in: context.loweredTypes)) does not declare."
                            + " A procedure is sent with a written call, and data"
                            + " past the declaration is read by declaring it,"
                            + " or through `Dictionary<Any>`"
                    )
                }

                if let refusal = needless(.field(key)) { return refusal }

                current = field.fieldUnwrapped

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

        return .reads(optional ? current.admittingNull : current)
    }

    // The inner index paths a fold can settle. `items[C]` reads its index from
    // a constant, so the index is knowable now and no constant name survives
    // into the image. Recursive, because an index path holds index paths of its
    // own (`items[names[C]]`) and the promise is about all of them.
    private func foldedIndexReferences(
        _ path: Path,
        at place: Place,
        folding: Folding
    ) async throws -> Path {
        var folded: Path = []

        for segment in path.segments {
            folded.append(try await self.folded(segment, at: place, folding: folding))
        }

        return folded
    }

    // What a path write reaches, or why it may not. The head is a box; each
    // field on the way is one a declared type wrote `var`, or a field of a
    // type no declaration named; an element is written through its index. A
    // type that may be null is not written into, and neither is `Any`.
    private func writable(
        _ path: Path,
        from box: Binding,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> Writable {
        if let refusal = path.writtenThroughAbsence {
            return .refused(refusal)
        }

        var current = box.type
        var walked = Path(Array(path.segments.prefix(1)))

        for segment in path.segments.dropFirst() {
            walked.append(segment)

            // Whether the container being entered is a declared type's, which
            // is asked of this segment alone: a record written inline under a
            // `var` field is nobody's declaration.
            let declared = if case .named = current { true } else { false }

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

            // A name between the brackets is a path of its own, judged as
            // what the container reads it as: a position in a list and a key
            // in a map.
            case let (.indexRef(inner, _), .dictionary(entry)):
                if let refusal = keyReference(inner, in: environment, with: context, at: place) {
                    return .refused(refusal)
                }

                current = entry

            case let (.indexRef(inner, _), .array(element)):
                if let refusal = indexReference(inner, in: environment, with: context, at: place) {
                    return .refused(refusal)
                }

                current = element

            case let (.index, .array(element)):
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

    // The declaration an operand or a condition calls that answers only by
    // running, if any. An operand is data: the run reads it rather than
    // running it, so a call in it reaches a declaration that answers without
    // running. A value call and a construct in one are the load's to refuse,
    // since the text alone says where they stand.
    //
    // The module variables constness strikes a body for reading are not struck
    // here. Reading one is what reading a name is; what it costs a body is the
    // promise of answering the same thing twice, and an operand makes no such
    // promise.
    private func runs(in expression: Expression, given context: TypingContext) -> Name? {
        switch expression {
        case .literal, .reference, .closure, .apply, .block, .conditional, .loop, .attempt, .leave:
            return nil

        case let .cast(value, _, _):
            return runs(in: value, given: context)

        case let .array(array):
            return array.lazy.compactMap { element in runs(in: element, given: context) }.first

        case let .record(record):
            return record.values.lazy.compactMap { field in runs(in: field, given: context) }.first

        // A contract's procedure is answered by whatever type the value turns
        // out to be, so what a call through one reads as is what the contract
        // asked of every declaration answering it.
        case let .call(call):
            guard
                context.signature(of: call.selector) != nil,
                !context.isConst(call.selector)
            else {
                return call.arguments.lazy
                    .compactMap { argument in runs(in: argument, given: context) }.first
            }

            return call.selector
        }
    }

    // What a body answers, held to the `returns` written beside it: what the
    // result and every `return` that carried something out hold written into
    // the answer, each at its own place. A declaration and a closure literal
    // each write both in one document, so each asks here rather than working
    // the question out again further on.
    //
    // What opens to `Any` stands only where `Any` is declared.
    private func held(
        written answer: LiteralShape,
        answered: [Flow.Answer],
        to returns: TypeExpression?,
        bounds: [Name: Set<Name>],
        result: Expression?,
        at place: Place,
        in table: LoweredTypeTable,
        fulfillment: Fulfillment
    ) throws {
        for one in answered {
            try held(
                LiteralShape(one.literalShape, reading: one.reading),
                to: returns,
                bounds: bounds,
                at: one.place,
                in: table,
                fulfillment: fulfillment
            )
        }

        try held(
            answer,
            to: returns,
            bounds: bounds,
            at: place.part(result != nil ? .result : .returns),
            in: table,
            fulfillment: fulfillment
        )
    }

    // What a call answers: the declaration's returns, filled from the operands
    // where the declaration is generic. One statement of the rule, whichever
    // ask gathered the readings, and the filling is asked for lazily, so a
    // non-generic call never pays for it.
    private func answered(
        by signature: Signature?,
        answering: LoweredType?,
        filling filled: @autoclosure () -> [Name: LoweredType]
    ) -> LoweredType {
        guard let signature, let returns = answering else { return .any }
        guard signature.isGeneric else { return returns }

        return returns.filling(filled())
    }

    // The segments a stopped walk leaves stand as written, and an index
    // reference among them is a path of its own, judged wherever the outer
    // walk stops. What they reach is not read.
    private func asWritten(
        _ path: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        for segment in path.segments {
            guard case let .indexRef(inner, _) = segment else { continue }

            if let refusal = indexReference(inner, in: environment, with: context, at: place) {
                return .refused(refusal)
            }
        }

        return .reads(.any)
    }

    // The one machine that judges an index reference, wherever a walk meets
    // one, answering the refusal or nil. The inner path is a path of its own,
    // and what it reads stands where an `Int` is read.
    private func indexReference(
        _ inner: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> String? {
        switch reading(of: inner, in: environment, with: context, at: place) {
        case let .refused(reason):
            return reason

        case let .reads(innerType):
            guard !LoweredType.int.accepts(innerType, in: context.loweredTypes) else { return nil }

            return "index reference \(inner.rendered) reads"
                + " \(innerType.rendered(in: context.loweredTypes)), expected Int"
        }
    }

    // The one machine that judges a key the run settles, answering the
    // refusal or nil. A dictionary's names are strings, so what stands between
    // the brackets stands where a `String` is read.
    private func keyReference(
        _ inner: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> String? {
        switch reading(of: inner, in: environment, with: context, at: place) {
        case let .refused(reason):
            return reason

        case let .reads(innerType):
            guard !LoweredType.string.accepts(innerType, in: context.loweredTypes) else { return nil }

            return "key reference \(inner.rendered) reads"
                + " \(innerType.rendered(in: context.loweredTypes)), expected String"
        }
    }

    // One index path a fold settles. The recursion of the gathering above,
    // written out because reading a constant runs, and what runs is a call.
    private func folded(
        _ segment: PathSegment,
        at place: Place,
        folding: Folding
    ) async throws -> PathSegment {
        guard case let .indexRef(written, optionally) = segment else { return segment }

        // An index path indexed in turn by what only the run settles stays a
        // path however it is headed: the run reads it.
        let inner = try await foldedIndexReferences(written, at: place, folding: folding)

        guard let head = folding.settled(inner) else {
            return .indexRef(inner, optional: optionally)
        }

        let settled: Value

        do {
            settled = try await folding.read(inner, at: place)
        } catch {
            throw BuildError("reading constant '\(head)': \(error)", at: place)
        }

        // The mark rides the fold: which element or entry is read settles
        // now, whether the list or the map is there to be read stays the
        // run's question. A key is a name, so text that is not one names no
        // entry.
        switch settled {
        case let .int(index):
            guard index >= 0 else {
                throw BuildError(
                    "index reference \(inner.rendered) is \(index), and a whole number below zero is no position",
                    at: place
                )
            }

            return .index(index, optional: optionally)

        case let .string(key):
            guard let name = try? Name(key) else {
                throw BuildError("key reference \(inner.rendered) is '\(key)', which is not a name", at: place)
            }

            return .key(name, optional: optionally)

        default:
            throw BuildError(
                "index reference \(inner.rendered) is \(settled.nominal), expected Int or String",
                at: place
            )
        }
    }

    // The gate a refusal passes: judging throws it, and the probing ask has
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

    // An operand is data: the run reads it rather than running it. A call to a
    // declaration that answers only by running is refused here, where the
    // operand is written, rather than found when the reading reaches it.
    private func held(
        _ expression: Expression,
        asOperand place: Place,
        given context: TypingContext,
        when ask: Ask
    ) throws {
        guard let selector = runs(in: expression, given: context) else { return }

        try refuse(
            "reads '\(selector)', which answers only by running, and an"
                + " operand is read rather than run. A procedure that runs"
                + " is called by a statement, whose name the operand reads",
            at: place,
            when: ask
        )
    }

    // A condition chooses a way through a body, so what it reads has to be a
    // `Bool`, and a value read as `Any` is one once a cast says so.
    private func held(
        _ reading: LoweredType,
        asCondition place: Place,
        in context: TypingContext,
        when ask: Ask
    ) throws {
        guard !LoweredType.bool.accepts(reading, in: context.loweredTypes) else { return }

        try refuse(
            "reads \(reading.rendered(in: context.loweredTypes)), and a condition"
                + " chooses a way through a body, so it answers a Bool",
            at: place,
            when: ask
        )
    }

    // The walk. Each subexpression is judged in the environment the ones
    // before it left behind, which is the environment the run gives it.
    // `name` is what the statement this expression is the value of
    // introduces, which a loop binds its round under and an attempt its
    // failure.
    private func inspected(
        _ expression: Expression,
        naming name: Name?,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> Inspection {
        switch expression {
        case let .literal(value):
            return Inspection(
                rewritten: expression,
                reading: LoweredType(literal: value, in: context.loweredTypes),
                literalShape: LiteralShape(literal: value, in: context.loweredTypes)
            )

        // Nothing comes back from here, so there is no value to have a type.
        // `Never` fits wherever it is written, and what evaluating the carried
        // value wrote left with the leave.
        case let .leave(leave):
            // What the procedure answers this way. Only a `return` reaches the
            // caller (a `break` ends its loop and a `continue` its round) and
            // one carrying nothing hands back the null a body with no result
            // hands back, which is the run's own answer for it.
            func answering(_ flowed: Flow, carrying carried: Inspection?) -> Flow {
                guard leave.reach == .procedure else { return flowed }

                var answering = flowed
                answering.answered = flowed.answered + [
                    (carried?.reading ?? .null, carried?.literalShape, place)
                ]

                return answering
            }

            guard let value = leave.value else {
                return Inspection(
                    rewritten: expression,
                    reading: .never,
                    flow: answering(Flow(), carrying: nil).leaving(to: Flow.Reach(leave))
                )
            }

            // What a `return` carries stands where the body declares its
            // answer, a closure literal included.
            let answer = leave.reach == .procedure ? ask.answer : nil
            let carried = try await inspected(
                answer.map { answer in answer.completing(value, in: context.loweredTypes) } ?? value,
                naming: nil,
                at: place.child(.held),
                in: environment,
                with: context,
                ask: ask
            )

            let handed = answer.map { answer in answer.written(carried.rewritten, in: context.loweredTypes) } ?? carried.rewritten
            var judgements = carried.judgements

            if let answer {
                judgements.record(names: answer.naming(carried.rewritten, at: place.child(.held), in: context.loweredTypes))
            }

            return Inspection(
                rewritten: ask.rewrites
                    ? .leave(
                        Leave(reach: leave.reach, target: leave.target, value: handed)
                    )
                    : expression,
                calls: carried.calls,
                judgements: judgements,
                reading: .never,
                flow: answering(carried.flow, carrying: carried).leaving(to: Flow.Reach(leave))
            )

        // A path names something that has to exist just as a selector does, so
        // judging refuses what does not resolve. A constant-headed path is
        // data the moment it is read, so under a folding scope it is judged
        // first (the same rules as any path) and then becomes that data.
        case let .reference(path):
            let reached = Flow(read: Set(path.expandingIndexReferences.compactMap(\.head)))

            switch reading(of: path, in: environment, with: context, at: place) {
            case let .refused(reason):
                try refuse(reason, at: place, when: ask)

                return Inspection(rewritten: expression, reading: .any, flow: reached)

            case let .reads(read):
                guard case let .judging(folding, _, _) = ask, let folding else {
                    return Inspection(rewritten: expression, reading: read, flow: reached)
                }

                // An inner index path may read a constant too. `items[C]` folds
                // its index the way a whole constant path folds, so no constant
                // name survives into the image. One indexed by what only the run
                // settles (`digits[ch]`) cannot fold: it stays a path, and the
                // lowering binds the constant in the body for the run to read.
                let settled = try await foldedIndexReferences(path, at: place, folding: folding)

                guard let head = folding.settled(settled) else {
                    return Inspection(rewritten: .reference(settled), reading: read, flow: reached)
                }

                do {
                    let value = try await folding.read(settled, at: place)

                    return Inspection(
                        rewritten: .literal(value),
                        reading: LoweredType(of: value, in: context.loweredTypes)
                            .refined(by: read, fixed: true, in: context.loweredTypes),
                        flow: reached
                    )
                } catch {
                    throw BuildError("reading constant '\(head)': \(error)", at: place)
                }
            }

        case let .array(array):
            var environment = environment
            var rewritten: [Expression] = []
            var calls: [CallSite] = []
            var judgements = JudgementTable()
            var flowed = Flow()
            var element: LoweredType?
            var first: LoweredType?
            var items: [LiteralShape]?

            for (position, member) in array.enumerated() {
                let inner = try await inspected(
                    member,
                    naming: nil,
                    at: place.child(.element(position)),
                    in: environment,
                    with: context,
                    ask: ask
                )

                inner.flow.apply(to: &environment)
                flowed = flowed.followed(by: inner.flow)
                calls += inner.calls
                judgements.absorb(inner.judgements)
                element = element?.joined(inner.reading) ?? inner.reading

                // Part by part only once a part is not what every one before
                // it is, which its reading then says alone.
                if items == nil, inner.literalShape != nil || first.map({ first in first != inner.reading }) == true {
                    items = Array(repeating: .part(first ?? inner.reading), count: position)
                }

                first = first ?? inner.reading
                items?.append(inner.written)
                rewritten.append(inner.rewritten)
            }

            // A literal element read beside fractions is the fraction it
            // names, since the list holds one type.
            if let element, ask.rewrites {
                rewritten = rewritten.map { item in element.written(item, in: context.loweredTypes) }
            }

            return Inspection(
                rewritten: ask.rewrites ? .array(rewritten) : expression,
                calls: calls,
                judgements: judgements,
                reading: .array(element ?? .never),
                flow: flowed,
                literalShape: array.isEmpty ? .list([]) : items.map(LiteralShape.list)
            )

        // A cast is where a reading the walk could not judge becomes one it
        // can. The type is the author's claim, so it is the reading from here
        // on, and the run is left the one question the build cannot answer,
        // which is what actually arrived.
        //
        // A claim the types already prove is refused, for the reason a needless
        // `?.` is: the mark of a doubt where no doubt is left says nothing, and
        // a spelling that says nothing is a reading gone wrong.
        case let .cast(value, type, optional):
            let inner = try await inspected(
                value,
                naming: nil,
                at: place.child(.subject(optional: optional)),
                in: environment,
                with: context,
                ask: ask
            )
            // A cast reads a value and is no place a literal is written into,
            // so a whole literal in what it reads is the Int it is, at every
            // depth.
            let read = inner.reading.asHeld
            let claim = type.lowered(in: context.loweredTypes)
            
            // Both refusals ask the types themselves, whether or not the
            // reading is fully proven.
            //
            // Needless means the claim and the reading are the same type, not
            // that one would accept the other. `accepts` holds between `Int?`
            // and `Int`, and a reading of `Int?` cast to `Int` still says
            // something the run has to answer. Record names
            // count at every depth: reading a nameless record as a declared
            // one attaches the name, so it is never a cast of what the value
            // already is.
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

            let couldBe = claim.couldBothHold(reading: read, in: context.loweredTypes)

            if !couldBe {
                // Neither could ever be the other, and the reading proves what
                // it is, so this cast cannot succeed on any run. `as` would
                // refuse every time and `as?` would answer null every time,
                // which is the silent permanent null `as?` exists to avoid
                // being. What is decidable before a run is decided before it.
                try refuse(
                    "reads \(read.rendered(in: context.loweredTypes)) as \(claim.rendered(in: context.loweredTypes)),"
                        + " and no value is both."
                        + " A cast names a type the value may turn out to"
                        + " have, and this one it never can",
                    at: place,
                    when: ask
                )
            } else if claim == read
                || handed == read {
                // Asked of the reading this hands on, not of the spelling that
                // made it. `payload as? Int` hands on `Int?` and `payload as?
                // Maybe` hands on `Maybe`. The same type by two spellings, and
                // reading the question off the spelling let the second catch a
                // repeat that the first waved through.
                try refuse(
                    "reads \(read.rendered(in: context.loweredTypes)) as \(claim.rendered(in: context.loweredTypes)),"
                        + " which it already is."
                        + " A cast opens what the types do not prove,"
                        + " and here they do",
                    at: place,
                    when: ask
                )
            }

            var flow = inner.flow

            if failsHere(expression, given: context) {
                flow.fail()
            }

            return Inspection(
                // The author's spelling stands, so a document written back
                // out keeps the declaration it leaned on.
                rewritten: ask.rewrites
                    ? .cast(inner.rewritten, as: type, optional: optional)
                    : expression,
                calls: inner.calls,
                judgements: inner.judgements,
                // `?` is asked of the fact: a type that already holds null is
                // not wrapped again.
                reading: handed,
                flow: flow
            )

        // In name order. The order the run evaluates fields in, so what one
        // field's write means to the next is the same fact at the run.
        case let .record(record):
            var environment = environment
            var rewritten: [Name: Expression] = [:]
            var calls: [CallSite] = []
            var judgements = JudgementTable()
            var flowed = Flow()
            var fields: [Name: LoweredType] = [:]
            var shapes: [Name: LiteralShape] = [:]

            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                let inner = try await inspected(
                    field,
                    naming: nil,
                    at: place.child(.field(name)),
                    in: environment,
                    with: context,
                    ask: ask
                )

                inner.flow.apply(to: &environment)
                flowed = flowed.followed(by: inner.flow)
                calls += inner.calls
                judgements.absorb(inner.judgements)
                fields[name] = inner.reading
                shapes[name] = inner.literalShape
                rewritten[name] = inner.rewritten
            }

            return Inspection(
                rewritten: ask.rewrites ? .record(rewritten) : expression,
                calls: calls,
                judgements: judgements,
                reading: .record(fields),
                flow: flowed,
                literalShape: .record(fields.mapValues(LiteralShape.part).merging(shapes) { _, shape in shape })
            )

        // A closure literal carries the signature it declared, and running one
        // is not this flow's business. What it writes it writes when it is
        // called, and the flow here is the flow of the making. Judging still
        // follows the body even though nothing can say whether it is ever
        // called: the warrant is compilation, and a body that never runs still
        // has to compile. It sees what surrounds it plus what it declares.
        // Constness is read the same way a declaration's is. From what the body
        // calls.
        case let .closure(written):
            // The Validator refuses a closure literal that is not a body.
            guard case let .body(block) = written.implementation else {
                assertionFailure("a closure literal reached the type check without a body")

                return Inspection(rewritten: expression, reading: .any)
            }

            // A closure's `some T` is the name the procedure around it filled,
            // held to the bounds that procedure declared; its own signature
            // writes none.
            var procedure = written.with(signature: written.signature.bounded(by: context.bounds))
            var rewritten = expression
            var calls: [CallSite] = []
            var judgements = JudgementTable()
            var body = block

            // What the closure takes from where it was written: every name
            // there but the ones it declares, which are its own whatever a
            // name of the same spelling outside holds. The writes it makes
            // and the procedures it calls are judged against this.
            let declared = Set(procedure.signature.names)
            let outside = environment.filter { name, _ in !declared.contains(name) }

            // A box the closure takes is held, inside it, to what it reads as
            // here: a write the closure makes is judged against that type
            // and settles to it, and leaves the box reading it.
            let taken = outside.mapValues { binding in
                binding.taken(to: binding.type)
            }

            // The body read under the ask this walk answers: what it reaches
            // from outside is what the closure takes, which either ask needs.
            // A closure literal the body answers, at any depth, is completed
            // by the type the closure answers. Its body reads the names of
            // the procedure around it, so a closure it writes does too.
            let promised = procedure.signature.returns?.lowered(in: context.loweredTypes, bounds: procedure.signature.bounds)
            let inner = try await inspected(
                block: promised.map { promised in promised.completing(block, in: context.loweredTypes) } ?? block,
                at: place.child(.closure),
                in: taken.merging(procedure.signature.environment(in: context.loweredTypes)) {
                    _, own in own
                },
                with: context,
                ask: ask.answering(promised)
            )

            // A closure that writes no `returns`, written where nothing
            // completes it, answers what its body hands back, each way out
            // read as a name holds it, the way a declaration that writes none
            // does. The answer is written into its signature, so the run
            // reads the closure as the build did.
            if procedure.signature.returns == nil {
                let answered = inner.flow.answer(resulting: inner.reading)

                procedure = procedure.with(
                    signature: Signature(parameters: procedure.signature.parameters, returns: answered.spelled(in: context.loweredTypes))
                        .bounded(by: context.bounds)
                )
            }

            // A box the closure takes is one it reads and writes when it is
            // called, as the type it reads as here. What it reaches it hands
            // on as read, for a closure around it.
            let reached = inner.flow.reached.subtracting(declared)
            var flow = Flow(read: reached)

            for name in reached {
                guard let taken = outside[name]?.takenType else { continue }

                flow.hold(taken, on: name)
            }

            if case let .judging(_, fulfillment, _) = ask {
                // What the closure writes into a name it captured has to fit
                // what the name holds: the closure runs when it is called,
                // and the body that declared the variable reads it as the
                // type it gave it. A write here retypes nothing outside.
                let writes = inner.flow.ways.flatMap { way in
                    way.written.map { name, write in (name: name, type: write.type) }
                }

                for (name, wrote) in writes.sorted(by: { $0.name < $1.name }) {
                    guard let held = outside[name]?.type else { continue }

                    guard fits(.part(wrote), into: held, of: outside[name], in: context.loweredTypes) else {
                        throw BuildError(
                            "writes '\(name)', which it captured, as"
                                + " \(wrote.rendered(in: context.loweredTypes)). The body it captured"
                                + " from holds it as \(held.rendered(in: context.loweredTypes))",
                            at: place.child(.closure)
                        )
                    }

                    if let refusal = refusal(
                        holding: wrote,
                        to: held,
                        as: "writes '\(name)', which it captured, as",
                        in: context.loweredTypes,
                        fulfillment: fulfillment,
                        at: place.child(.closure)
                    ) {
                        throw BuildError(refusal, at: place.child(.closure))
                    }
                }

                try held(
                    written: LiteralShape(inner.literalShape, reading: inner.reading),
                    answered: inner.flow.answered,
                    to: procedure.signature.returns,
                    bounds: procedure.signature.bounds,
                    result: inner.block.result,
                    at: place.child(.closure),
                    in: context.loweredTypes,
                    fulfillment: fulfillment
                )

                body = promised.map { promised in promised.written(inner.block, in: context.loweredTypes) } ?? inner.block
                calls = inner.calls
                judgements = inner.judgements

                if let promised {
                    judgements.record(names: promised.naming(inner.block, at: place.child(.closure), in: context.loweredTypes))
                }
            }

            // A module variable the body reads strikes constness under either
            // ask, so the probing walk and the judging one read one closure
            // as one type.
            let reading = context.variables.subtracting(declared)

            // A name this closure captured carries what the slot it came from
            // said about it, and its own parameters shadow any it captured.
            let bound = procedure.signature.environment(in: context.loweredTypes)
                .merging(outside) { own, _ in own }
                .compactMapValues(\.declaredType)

            let const = Derivation().isConst(
                body,
                declaring: procedure.signature.ownedParameters,
                given: context.isConst,
                reading: reading,
                bound: bound,
                taking: context.signature(of:),
                in: context.loweredTypes
            )
            let isolated = Derivation().isIsolated(
                body,
                declaring: declared,
                given: context.isIsolated,
                bound: bound,
                taking: context.signature(of:),
                in: context.loweredTypes
            )

            if case .judging = ask {
                rewritten = .closure(
                    Procedure(
                        description: procedure.description,
                        signature: procedure.signature,
                        implementation: .body(body)
                    )
                )

                judgements.record(
                    .closure(
                        constness: const ? .const : .unstated,
                        isolation: isolated ? .isolated : .unstated,
                        failing: Derivation().failing(body, given: context.failing(of:))
                    ),
                    at: place.child(.closure)
                )
            } else if procedure.signature != written.signature {
                rewritten = .closure(procedure)
            }

            return Inspection(
                rewritten: rewritten,
                calls: calls,
                judgements: judgements,
                reading: TypeExpression.procedure(
                    procedure.signature.type,
                    const ? .const : .unstated,
                    isolated ? .isolated : .unstated
                )
                .lowered(in: context.loweredTypes, bounds: procedure.signature.bounds),
                flow: flow
            )

        // Which value is called is settled at the run, and what it answers is
        // the slot's to say under either ask: a procedure type that wrote
        // `returns` answers that, and one that wrote none opens to `Any`. Its
        // operands are data, held as operands below, and write nothing. What
        // the call carries out is the boxes it took: a variable it hands in
        // place, and what a closure among its operands took.
        case let .apply(callee, arguments):
            // One by one, because a loop over the values alone reports the
            // third operand from the place the first was.
            if case .judging = ask {
                try held(callee, asOperand: place.child(.callee), given: context, when: ask)

                for (position, argument) in arguments.enumerated() {
                    try held(argument, asOperand: place.child(.argument(position)), given: context, when: ask)
                }
            }

            let called = try await inspected(
                callee,
                naming: nil,
                at: place.child(.callee),
                in: environment,
                with: context,
                ask: ask
            )

            // Read once, and every judgement below asks this reading: whether
            // it could be called, what it takes and what it answers.
            let callee = called.reading.slotUnwrapped
            let answers: LoweredType

            if case let .procedure(_, returns?, _, _) = callee {
                answers = returns
            } else {
                answers = .any
            }

            // A closure literal written here, at any depth, is completed by
            // the type it is written into.
            let arguments = arguments.enumerated().map { position, argument in
                guard case let .procedure(parameters?, _, _, _) = callee, parameters.indices.contains(position) else {
                    return argument
                }

                return parameters[position].completing(argument, in: context.loweredTypes)
            }

            // The positions the call hands a variable in place: the ones the
            // slot's type marks `inout`, where the build reads its parameters,
            // and none where it does not.
            var handed: [Int] = []

            if case let .procedure(parameters?, _, _, _) = callee {
                handed = parameters.indices.filter { position in parameters[position].isInout }
            }

            // What the operands took is taken by the call, and so is what it
            // hands in place.
            var flow = heldInPlace(arguments, at: handed, in: environment)

            flow = flow.followed(by: called.flow)

            guard case let .judging(_, fulfillment, _) = ask else {
                for (position, argument) in arguments.enumerated() {
                    flow = flow.followed(by: try await inspected(
                        argument,
                        naming: nil,
                        at: place.child(.argument(position)),
                        in: environment,
                        with: context,
                        ask: ask
                    ).flow)
                }

                if failsHere(expression, given: context) {
                    flow.fail()
                }

                return Inspection(rewritten: expression, reading: answers, flow: flow)
            }

            // Null is not called through, the way it is not read through.
            if case .nullable = callee {
                throw BuildError(
                    "calls a value of \(called.reading.rendered(in: context.loweredTypes)), which may be null",
                    at: place.child(.callee)
                )
            }

            guard callee.couldBeProcedure(in: context.loweredTypes) else {
                throw BuildError(
                    "calls a value of \(called.reading.rendered(in: context.loweredTypes)),"
                        + " and only a procedure can be called",
                    at: place.child(.callee)
                )
            }

            // A value whose type writes no parameters says nothing the build
            // can hold an argument against, so it is called once a cast says
            // what procedure it is.
            guard case let .procedure(parameters?, _, _, _) = callee else {
                throw BuildError(
                    "calls a value of \(called.reading.rendered(in: context.loweredTypes)),"
                        + " which writes no parameters it takes. A cast says what procedure it is",
                    at: place.child(.callee)
                )
            }

            let subject = "calls a value of \(called.reading.rendered(in: context.loweredTypes))"

            try refuseCount(handing: arguments.count, taking: parameters.count, as: subject, at: place)

            var rewritten: [Expression] = []
            var calls = called.calls
            var judgements = called.judgements
            var sent: [LoweredType] = []
            var shapes: [Int: LiteralShape] = [:]

            for (position, argument) in arguments.enumerated() {
                let inner = try await inspected(
                    argument,
                    naming: nil,
                    at: place.child(.argument(position)),
                    in: environment,
                    with: context,
                    ask: ask
                )

                rewritten.append(inner.rewritten)
                sent.append(inner.written.folded)
                shapes[position] = inner.literalShape
                calls += inner.calls
                judgements.absorb(inner.judgements)
                flow = flow.followed(by: inner.flow)
            }

            // The arguments are handed by position the way a call's are, and
            // held to what the slot's type takes by the judgement a call to a
            // declaration is held by. What is written into a slot as a
            // literal is read as the slot reads it, and a record built there
            // is built as the record the slot reads.
            for (position, (argument, slot)) in zip(rewritten, parameters).enumerated() {
                judgements.record(names: slot.naming(argument, at: place.child(.argument(position)), in: context.loweredTypes))
            }

            rewritten = zip(rewritten, parameters).map { argument, slot in slot.written(argument, in: context.loweredTypes) }

            try handedInPlace(arguments, to: parameters, in: environment, with: context, at: place, when: ask)

            // A type parameter the slot names is the body's own, which no
            // call fills and no run can hold a value to, so what stands
            // there is a value of it already, the way a write into a box
            // of it is.
            for (position, slot) in parameters.enumerated() where !handed.contains(position) && slot.namesParameter {
                let written = LiteralShape(shapes[position], reading: sent[position])
                let holds = written.everyPart(along: slot, inPlace: false, in: context.loweredTypes) { slot, part, _ in
                    !slot.namesParameter || slot.accepts(part.folded, in: context.loweredTypes, rigid: true)
                }

                if !holds {
                    try refuse(
                        "\(subject) with \(written.rendered(in: context.loweredTypes)) at position \(position),"
                            + " where its slot reads \(slot.rendered(in: context.loweredTypes)): a type parameter"
                            + " the body does not fill takes only a value of it",
                        at: place.child(.argument(position)),
                        when: ask
                    )
                }
            }

            try check(
                rewritten,
                reading: sent,
                shaped: shapes,
                against: parameters,
                naming: nil,
                as: subject,
                in: context.loweredTypes,
                writing: fulfillment,
                at: place
            )

            judgements.record(.apply(inPlace: handed), at: place)

            if failsHere(expression, given: context) {
                flow.fail()
            }

            return Inspection(
                rewritten: .apply(called.rewritten, arguments: rewritten),
                calls: calls,
                judgements: judgements,
                reading: answers,
                flow: flow
            )

        // A call answers what its callee declared, which is the fact this whole
        // walk exists to carry. A declaration with a type parameter in it
        // answers nothing until this call fills it, so the parameters are read
        // from what was actually sent and the answer comes back with them
        // filled, and only a generic answer reads the operands at all, so under
        // the probing ask only a generic call pays for taking their readings.
        // The operands are data, held as operands below, so nothing here
        // writes: every operand stands in the one environment the call stands
        // in.
        case let .call(call):
            let signature = context.signature(of: call.selector)

            // What the operands took is taken by the call, and so is what it
            // hands in place.
            let mayFail = failsHere(expression, given: context)
            let slots = context.slots(of: call.selector)
            var flow = heldInPlace(
                call.arguments,
                at: slots.indices.filter { position in slots[position].type.isInout },
                in: environment
            )

            guard case .judging = ask else {
                var readings: [LoweredType] = []

                for (position, argument) in call.arguments.enumerated() {
                    let inner = try await inspected(
                        argument,
                        naming: nil,
                        at: place.child(.argument(position)),
                        in: environment,
                        with: context,
                        ask: ask
                    )

                    readings.append(inner.written.folded)
                    flow = flow.followed(by: inner.flow)
                }

                if mayFail {
                    flow.fail()
                }

                return Inspection(
                    rewritten: expression,
                    reading: answered(
                        by: signature,
                        answering: context.answer(of: call.selector),
                        filling: substitution(over: slots, readings: readings, in: context.loweredTypes).readings
                    ),
                    flow: flow
                )
            }

            let argumentPlaces = call.arguments.indices.map { position in place.child(.argument(position)) }

            // Every operand of this call: what a slot takes has nothing to do
            // with whether the operand written into it is read or run. Placed
            // one by one, because a loop over the values alone reports the
            // third operand from the place the first was.
            for (position, argument) in call.arguments.enumerated() {
                try held(argument, asOperand: argumentPlaces[position], given: context, when: ask)
            }

            // A selector this document cannot name is refused where the walk
            // meets it. Its answer is unknown, and a dot on an unknown answer
            // would be refused first for what the dot reads, which is not what
            // the author got wrong.
            guard let signature else {
                guard !context.concealed.contains(call.selector) else {
                    throw BuildError.concealed(call.selector, at: place)
                }

                throw BuildError(
                    "sends '\(call.selector)', which no module in this link declares",
                    at: place
                )
            }

            try refuseCount(
                handing: call.arguments.count,
                taking: signature.parameters.count,
                as: "sending '\(call.selector)'",
                at: place
            )

            var arguments: [Expression] = []
            var sent: [LoweredType] = []
            var shapes: [Int: LiteralShape] = [:]
            var calls: [CallSite] = []
            var judgements = JudgementTable()

            for (position, written) in call.arguments.enumerated() {
                // A closure literal written here, at any depth, is completed
                // by the type it is written into.
                let argument = signature.parameters.indices.contains(position)
                    ? signature.parameters[position].type.lowered(in: context.loweredTypes, bounds: signature.bounds)
                        .completing(written, in: context.loweredTypes)
                    : written
                let inner = try await inspected(
                    argument,
                    naming: nil,
                    at: argumentPlaces[position],
                    in: environment,
                    with: context,
                    ask: ask
                )

                arguments.append(inner.rewritten)
                sent.append(inner.written.folded)
                shapes[position] = inner.literalShape
                calls += inner.calls
                judgements.absorb(inner.judgements)
                flow = flow.followed(by: inner.flow)
            }

            let filled = substitution(over: slots, readings: sent, in: context.loweredTypes).readings

            let taking = slots.map { slot in slot.type.filling(filled) }

            try handedInPlace(
                call.arguments,
                to: taking,
                in: environment,
                with: context,
                at: place,
                when: ask
            )

            // A slot the body's own type parameter fills stands for whatever
            // filled the body's, so it takes only a value of that parameter.
            for position in loose(taking: taking, readings: sent, shaped: shapes, filling: filled, in: context.loweredTypes) {
                try refuse(
                    "sending '\(call.selector)' with \(sent[position].rendered(in: context.loweredTypes)) at position"
                        + " \(position), where its slot reads \(taking[position].rendered(in: context.loweredTypes)):"
                        + " a type parameter the body does not fill takes only a value of it",
                    at: argumentPlaces[position],
                    when: ask
                )
            }

            // What is written into each slot as a literal is read as the slot
            // reads it, and a record built there is built as the record the
            // slot reads.
            for (position, (argument, slot)) in zip(arguments, taking).enumerated() {
                judgements.record(names: slot.naming(argument, at: argumentPlaces[position], in: context.loweredTypes))
            }

            let rewritten = Call(
                selector: call.selector,
                arguments: zip(arguments, taking).map { argument, slot in slot.written(argument, in: context.loweredTypes) }
            )

            let reading = answered(
                by: signature,
                answering: context.answer(of: call.selector),
                filling: filled
            )

            if mayFail {
                flow.fail()
            }

            return Inspection(
                rewritten: .call(rewritten),
                calls: [
                    CallSite(
                        call: rewritten,
                        place: place,
                        readings: sent,
                        shapes: shapes
                    )
                ] + calls,
                judgements: judgements,
                reading: reading,
                flow: flow
            )

        case let .block(block):
            let inner = try await inspected(block: block, at: place.child(.held), in: environment, with: context, ask: ask)

            return Inspection(
                rewritten: ask.rewrites ? .block(inner.block) : expression,
                calls: inner.calls,
                judgements: inner.judgements,
                reading: inner.reading,
                flow: inner.flow,
                literalShape: inner.literalShape
            )

        // A conditional answers nothing. A condition chooses a way through the
        // body, not a value; the one thing its type still says is `Never`, when
        // both arms have it. The condition runs every way and the arms are the
        // fork, judged in the environment the condition left: an arm every run
        // takes does not exist unless both are written (a conditional with no
        // other arm makes every write indefinite) and an arm that leaves hands
        // on nothing, so the write the staying arm makes is definite again: the
        // ways that finish all made it. Unreached arms are followed on purpose.
        case let .conditional(condition, then, otherwise):
            // A condition is data and writes nothing, so the arms stand in the
            // environment the conditional stands in.
            let head = try await inspected(
                condition,
                naming: nil,
                at: place.child(.condition(of: .conditional)),
                in: environment,
                with: context,
                ask: ask
            )

            try held(condition, asOperand: place.child(.condition(of: .conditional)), given: context, when: ask)
            try held(head.reading, asCondition: place.child(.condition(of: .conditional)), in: context, when: ask)

            let inside = environment

            let taken = try await inspected(then, at: place.child(.then), in: inside, with: context, ask: ask)

            guard let otherwise else {
                return Inspection(
                    rewritten: ask.rewrites
                        ? .conditional(head.rewritten, then: taken.body, else: nil)
                        : expression,
                    calls: head.calls + taken.calls,
                    judgements: head.judgements.absorbing(taken.judgements),
                    reading: .null,
                    flow: head.flow.followed(
                        by: try taken.flow.joined(
                            with: Flow(),
                            meeting: meeting(at: place, in: context.loweredTypes, when: ask)
                        )
                    )
                )
            }

            let declined = try await inspected(
                otherwise,
                at: place.child(.otherwise),
                in: inside,
                with: context,
                ask: ask
            )

            return Inspection(
                rewritten: ask.rewrites
                    ? .conditional(head.rewritten, then: taken.body, else: declined.body)
                    : expression,
                calls: head.calls + taken.calls + declined.calls,
                judgements: head.judgements.absorbing(taken.judgements, declined.judgements),
                reading: taken.reading == .never && declined.reading == .never ? .never : .null,
                flow: head.flow.followed(
                    by: try taken.flow.joined(
                        with: declined.flow,
                        meeting: meeting(at: place, in: context.loweredTypes, when: ask)
                    )
                )
            )

        // A loop answers its body's declared result, and null when it has none.
        // A round may run no time at all, so nothing a round writes is
        // definite. A `break` or a `continue` of this loop stops here, and the
        // ways they took are absorbed rather than handed on; a `return`, or
        // one naming a loop further out, goes on past it. A round also follows
        // the rounds that finished or continued, so the condition and the body
        // read the settled environment. The one the rounds' own writes
        // have already joined into. Readings that cycle instead of settling
        // would be widened to `Any` behind the author's back. Judging says so
        // out loud, where a refusal can carry the reason; the probing ask stays
        // total and takes the widened answer.
        case let .loop(condition, body):
            let round = name

            // The fixpoint probes a round as it runs, the condition then the
            // statements. The rounds are what leave things for one another,
            // and the result never runs between rounds. The probe reads, so a
            // probing asker takes the settled probe of the statements as its
            // own walk; judging walks once more for the rewrite.
            let entry = rounded(environment, as: round)
            let meets = meeting(at: place, in: context.loweredTypes, when: ask)
            let climbing = meeting(at: place, in: context.loweredTypes, when: .probing)
            let (seeded, probed, converged) = try await settled(
                from: entry,
                start: { flow in try flow.start(of: round, meeting: climbing) }
            ) { seeding -> (round: BodyWalk, flow: Flow) in
                let asked = try await inspected(
                    condition,
                    naming: nil,
                    at: place.child(.condition(of: .loop)),
                    in: seeding,
                    with: context,
                    ask: .probing
                )
                var asking = seeding

                asked.flow.apply(to: &asking)

                let walk = try await inspected(
                    body.body,
                    at: place.child(.held).child(.body),
                    in: asking,
                    with: context,
                    ask: .probing
                )

                return (walk, asked.flow.followed(by: walk.flow))
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
                naming: nil,
                at: place.child(.condition(of: .loop)),
                in: seeded,
                with: context,
                ask: ask
            )

            try held(condition, asOperand: place.child(.condition(of: .loop)), given: context, when: ask)
            try held(head.reading, asCondition: place.child(.condition(of: .loop)), in: context, when: ask)

            // The statements run where the condition left things.
            var asked = seeded

            head.flow.apply(to: &asked)

            let rounds = ask.rewrites
                ? try await inspected(body.body, at: place.child(.held).child(.body), in: asked, with: context, ask: ask)
                : probed

            // A round as it runs: the condition, then the body. The loop
            // runs it from where none or more rounds before left things, so
            // every way a round hands further out went through that start. It
            // ends where the condition declines there, or where a round of it
            // broke or continued.
            let turn = head.flow.followed(by: rounds.flow)
            let start = try turn.start(of: round, meeting: meets)
            let (stopped, outward) = try turn.gathered(where: { reach in reach.endsLoop(round) }, meeting: meets)
            let declined = head.flow.going.map { declined in start.followed(by: declined) }
            var ended = outward.preceded(by: start)

            ended.going = try Way.met(
                [declined, stopped.map { stopped in start.followed(by: stopped) }].compactMap { way in way },
                meeting: meets
            )

            // The result runs once, at whichever exit the run takes (a
            // condition that declines, after no round or after rounds that
            // finished or continued, or a round that breaks), and it reads
            // where the way the loop ends by leaves the names around it: the
            // loop's entry, with what that way wrote and took. A name the body
            // declared is the body's own, whatever the entry holds under that
            // spelling, and is null at the exit after no round (a name a scope
            // does not hold reads as null) so it reads back nullable, the same
            // join every some-ways write gets.
            var tail: Inspection?

            if let result = body.result {
                var exit = entry

                ended.apply(to: &exit)

                for (name, written) in rounds.environment where rounds.locals.contains(name) {
                    exit[name] = written.map { type in LoweredType.null.joined(type) }
                }

                tail = try await inspected(result, naming: nil, at: place.child(.held).child(.result), in: exit, with: context, ask: ask)
            }

            return Inspection(
                rewritten: ask.rewrites
                    ? .loop(
                        while: head.rewritten,
                        body: Block(body: rounds.body, result: tail?.rewritten ?? body.result)
                    )
                    : expression,
                calls: head.calls + rounds.calls + (tail?.calls ?? []),
                judgements: head.judgements.absorbing(rounds.judgements, tail?.judgements),
                reading: tail?.reading ?? .null,
                // The round is the loop's own name, read in the condition,
                // the body and the result alike.
                flow: (tail.map { tail in ended.followed(by: tail.flow.outside(rounds.locals)) } ?? ended)
                    .outside(Set([round].compactMap { $0 })),
                literalShape: tail?.literalShape
            )

        // The body and the rescue are two ways through, not a sequence. A body
        // that fails midway made some of its writes and the rescue runs then,
        // so what the body did on its way through and on every way that failed
        // may be there, whichever way ran and however far it got. That is the
        // environment the rescue reads as well as the one it writes. No write
        // on either side is definite. A way that left the body by a leave
        // lands where the leave lands; what it did before a failure is on the
        // way that failed.
        case let .attempt(block, rescue):
            let failure = name

            // What the rescue is there for. A body nothing can fail out of
            // leaves it a body no run reaches, and the author wrote it
            // expecting otherwise: what they are told is which failures the
            // build found, which is none.
            if Derivation().failing(block, given: context.failing(of:)).failsNothing {
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
                at: place.child(.held),
                in: environment,
                with: context,
                ask: ask
            )
            // The body runs. The ways a failure took meet, and the rescue
            // starts where they stood; where no way fails, no run reaches the
            // rescue.
            let meets = meeting(at: place, in: context.loweredTypes, when: ask)
            let (failed, past) = try attempted.flow.gathered(where: { reach in reach == .failure }, meeting: meets)
            let rescued = try await inspected(
                block: rescue,
                at: place.child(.rescue),
                in: caught(soaking: failed, failure: failure, in: environment, with: context),
                with: context,
                ask: ask
            )

            // What goes on past the body joins what goes on past the rescue,
            // and no write on either side is certain.
            var flow = try failed.map { failed in
                try past.joined(
                    with: rescued.flow.outside(Set([failure].compactMap { $0 })).preceded(by: failed),
                    meeting: meets
                )
            } ?? past

            flow.going = flow.going?.indefinite()

            // What the attempt answers is where its two ways meet.
            let shape = LiteralShape.either(
                LiteralShape(attempted.literalShape, reading: attempted.reading),
                LiteralShape(rescued.literalShape, reading: rescued.reading)
            )

            return Inspection(
                rewritten: ask.rewrites ? .attempt(attempted.block, rescue: rescued.block) : expression,
                calls: attempted.calls + rescued.calls,
                judgements: attempted.judgements.absorbing(rescued.judgements),
                reading: shape.folded,
                // The failure is bound in the rescue alone. The body reads
                // the names around the attempt.
                flow: flow,
                literalShape: shape
            )
        }
    }

    // A block: its body, then the result in the environment the body left
    // visible. A result after a statement no run comes back from is judging's
    // to refuse. The probing ask answers `Never` and moves on.
    private func inspected(
        block: Block,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> (block: Block, calls: [CallSite], judgements: JudgementTable, reading: LoweredType, literalShape: LiteralShape?, flow: Flow) {
        let body = try await inspected(
            block.body,
            at: place.child(.body),
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
                try refuse(Expression.resultAfterWhatNeverFinishes, at: place.child(.result), when: ask)
            }

            tail = nil
            reading = .never
            flow = body.flow
        } else if let result = block.result {
            let read = try await inspected(
                result,
                naming: nil,
                at: place.child(.result),
                in: body.environment,
                with: context,
                ask: ask
            )

            tail = read
            reading = read.reading
            flow = body.flow.followed(by: read.flow.outside(body.locals))
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
            body.judgements.absorbing(tail?.judgements),
            reading,
            tail?.literalShape,
            flow
        )
    }

    // A body read in order: the environment its statements leave behind,
    // `Never` where one of them ends every way through, and its outward writes.
    // Each statement's own binding included, except the names the body declared
    // itself, which die with it. Only the box a `set` writes outlives the
    // block. The one statement of the sequence rule, whichever ask is walking.
    private func inspected(
        _ body: Body,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> BodyWalk {
        var environment = environment
        var locals: Set<Name> = []
        var flowed = Flow()
        var rewritten: Body = []
        var calls: [CallSite] = []
        var judgements = JudgementTable()

        for (position, written) in body.statements.enumerated() {
            let here = place.statement(written, at: position)

            // A closure literal written here, at any depth, is completed by
            // the type it is written into.
            let statement = writtenInto(by: written.binding, in: environment, with: context, at: here).map { into in
                Statement(binding: written.binding, expression: into.completing(written.expression, in: context.loweredTypes))
            } ?? written

            let inner = try await inspected(
                statement.expression,
                naming: statement.binding?.introduced,
                at: here,
                in: environment,
                with: context,
                ask: ask
            )

            // A write's path settles its constant indexes the way a read's
            // path does, so no constant name survives into the image.
            var settled = statement.binding

            if case let .assignment(path)? = settled, case let .judging(folding, _, _) = ask, let folding {
                settled = .assignment(try await foldedIndexReferences(path, at: here, folding: folding))
            }

            rewritten.append(
                Statement(binding: settled, expression: inner.rewritten)
            )
            calls += inner.calls
            judgements.absorb(inner.judgements)

            // A write outlives the block it was written in, so a name written
            // anywhere inside this statement may hold something else by the
            // time the next one reads it, and bubbles outward, except through
            // the names this body declared itself.
            inner.flow.apply(to: &environment)
            flowed = flowed.followed(by: inner.flow.outside(locals))

            // A write reads the names its path indexes with.
            if case let .assignment(path)? = statement.binding {
                for name in path.expandingIndexReferences.compactMap(\.head) where !locals.contains(name) {
                    flowed.read.insert(name)
                }
            }

            // A statement no run comes back from ends the ways through this
            // body. What was written on the way to it leaves with it. One
            // predicate says so, and everything the fact decides reads it here:
            // judging refuses a name on the statement (a binding that cannot
            // happen) and anything written after it, which would never run.
            // What the syntactic leaves get at the load, a call gets here, where
            // the signature is known.
            if inner.flow.leaves || inner.reading == .never {
                if statement.binding != nil {
                    try refuseNeverBinding(at: here, when: ask)
                }

                if position != body.statements.count - 1 {
                    // The leaving statement, not what follows it: what an
                    // author has to change is the one that ends the body, and
                    // the load says the same thing from the same place.
                    try refuse(Expression.afterWhatNeverFinishes, at: here, when: ask)
                }

                // Judging refused anything after this statement above, so
                // what is handed back is exactly what was walked. A call that
                // never comes back ends the way here; where it may fail, the
                // call already sent the way to the attempt around it.
                return (
                    ask.rewrites ? rewritten : body,
                    calls,
                    judgements,
                    environment,
                    .never,
                    flowed.ended(),
                    locals
                )
            }

            // A name that says what it holds holds that. One that says
            // nothing holds what the build worked out from what it was given.
            // What a slot declared it holds is the derivation's to say, by the
            // rule its own walk binds a name by.
            let declaredType = statement.binding.flatMap { binding in
                Derivation().declaredType(
                    of: binding,
                    reading: statement.expression,
                    given: { name in environment[name]?.declaredType },
                    in: context.loweredTypes
                )
            }

            // What this statement's value is held to, and so what a literal in
            // it is written into: the type the name declares, or the one a
            // write is held to.
            var into: LoweredType?

            switch statement.binding {
            case let .constant(id, declared)?:
                locals.insert(id)
                environment[id] = Binding(
                    .fixed(declared: declaredType),
                    try held(inner.reading, writing: inner.written, declaredAs: declared, at: here, with: context, when: ask)
                )
                into = declared?.lowered(in: context.loweredTypes)

            case let .variable(id, declared)?:
                locals.insert(id)
                environment[id] = Binding(
                    declaredType.map(Binding.Holding.declared) ?? .assigned,
                    try held(inner.reading, writing: inner.written, declaredAs: declared, at: here, with: context, when: ask)
                )
                into = declared?.lowered(in: context.loweredTypes)

            // A write to a whole variable retypes it, the way a declaration
            // did, unless the box's type is fixed elsewhere, in which case what
            // is written has to fit. A box a closure or a call took reads as
            // the type it is held to after a whole write, since the taker may
            // write any value of that type later. A write through a path is
            // judged against the type the path reaches, and leaves the
            // variable's type as it was.
            case let .assignment(path)?:
                guard let id = path.head else { break }

                let written = inner.written

                switch environment[id] {
                case let binding? where binding.heldType != nil:
                    let held = try refuseUnfit(
                        written,
                        writtenTo: path,
                        into: binding,
                        in: environment,
                        with: context,
                        at: here,
                        when: ask
                    )

                    into = held

                    if case let .held(held) = binding.holding, path.segments.count == 1 {
                        environment[id] = Binding(.held(held), held)

                        if !locals.contains(id) {
                            flowed.land((held, true), on: id)
                        }
                    }

                case let binding? where binding.holding == .assigned:
                    if path.segments.count == 1 {
                        environment[id] = Binding(.assigned, inner.reading)

                        if !locals.contains(id) {
                            flowed.land((inner.reading, true), on: id)
                        }
                    } else {
                        // A write through a path leaves the box reading as it
                        // was, so what it writes settles to what the path
                        // reaches.
                        if let reached = try refuseUnfit(
                            written,
                            writtenTo: path,
                            into: binding,
                            in: environment,
                            with: context,
                            at: here,
                            when: ask
                        ) {
                            into = reached
                        }

                        if !locals.contains(id), let current = environment[id]?.type {
                            flowed.land((current, true), on: id)
                        }
                    }

                // The load holds a write's head to a variable.
                default:
                    break
                }

            // A nameless statement writes no name for a later reading to
            // find.
            case nil:
                break
            }

            // Literals are read as the type they land in reads them, and a
            // record built where it reads a declared record is built as that
            // record.
            if let into, ask.rewrites {
                judgements.record(names: into.naming(inner.rewritten, at: here, in: context.loweredTypes))
                rewritten = Body(
                    rewritten.statements.dropLast() + [
                        Statement(
                            binding: statement.binding,
                            expression: into.written(inner.rewritten, in: context.loweredTypes)
                        )
                    ]
                )
            }
        }

        return (ask.rewrites ? rewritten : body, calls, judgements, environment, .null, flowed, locals)
    }

    // What never finishes binds nothing, so a name on it promises a binding
    // that cannot happen. Asked exactly where the sequence rule finds a
    // statement that ends the body, so the two facts cannot part. The load
    // refuses the leaves it can see, and the build the calls only it can see.
    private func refuseNeverBinding(at place: Place, when ask: Ask) throws {
        try refuse(Expression.nameOnWhatNeverFinishes, at: place, when: ask)
    }

    // The environment a loop's insides read: the enclosing names plus the
    // round, where the loop binds one. One maker, because the fixpoint and
    // its asker both read it.
    private func rounded(
        _ environment: [Name: Binding],
        as round: Name?
    ) -> [Name: Binding] {
        guard let round else { return environment }

        return environment.merging([round: Binding(.fixed(declared: nil), Self.roundType)]) { _, new in new }
    }

    // The environment a rescue stands in: the entry, soaked with what the
    // ways that failed did before they failed (no write certain, none ruled
    // out) plus the failure under its name, where the attempt binds one.
    private func caught(
        soaking failed: Way?,
        failure: Name?,
        in environment: [Name: Binding],
        with context: TypingContext
    ) -> [Name: Binding] {
        var caught = environment

        failed?.indefinite().apply(to: &caught)

        if let failure {
            caught[failure] = Binding(.fixed(declared: nil), FailurePayload.declared.lowered(in: context.loweredTypes))
        }

        return caught
    }

    // A round's body, read in the environment its own earlier rounds may have
    // written. The caller hands the one reader its rounds have, the body's flow
    // joins into the entry environment, and the body is re-read until the
    // reading stops moving. The reader reads with the probing ask, because a
    // refusal mid-climb would be a refusal of an environment no run ever stands
    // in. A body that writes nothing outward settles on the first look; a chain
    // of writes settles one link per look, so the bound is the chain's own
    // size: the names the body writes, times the few steps the join ladder has.
    // Past it the readings are not climbing (they are cycling) and everything
    // the body writes falls to `Any`, or to the type it is held to where
    // something took it, over-wide and never wrong; the judging ask answers
    // that state out loud, where it can refuse.
    private func settled<Round>(
        from entry: [Name: Binding],
        start starting: (Flow) throws -> Way,
        read: ([Name: Binding]) async throws -> (round: Round, flow: Flow)
    ) async rethrows -> (environment: [Name: Binding], last: Round, converged: Bool) {
        var seeded = entry
        var (last, flow) = try await read(seeded)
        var start = Way()
        var steps = 0

        while true {
            var next = entry

            start = try starting(flow)
            start.apply(to: &next)

            guard next != seeded else { return (seeded, last, true) }
            guard steps < 3 * max(1, start.written.count) + 1 else { break }

            steps += 1
            seeded = next
            (last, flow) = try await read(seeded)
        }

        var widened = entry
        var widening = start

        widening.written = start.written.mapValues { _ in (.any, true) }
        widening.apply(to: &widened)

        // One more look in the widened environment, so what is handed back
        // was read where the caller will stand.
        let (settled, _) = try await read(widened)

        return (widened, settled, false)
    }

    // Where ways that each held one box meet. A taker on either way was
    // judged against the type its way held, and goes on writing that type
    // after the meeting, so the two ways agree only where they held the box
    // to one type, names resolved. Anything else is refused here.
    private func meeting(at place: Place, in table: LoweredTypeTable, when ask: Ask) -> Flow.Meeting {
        { name, one, other in
            guard one != other else { return }

            try refuse(
                "takes '\(name)' as \(one.rendered(in: table)) one way and as"
                    + " \(other.rendered(in: table)) another, and a taker on each way goes"
                    + " on writing its own type after the two meet",
                at: place,
                when: ask
            )
        }
    }

    // Whether a run may fail at this node itself, by the one judgement of it.
    private func failsHere(_ expression: Expression, given context: TypingContext) -> Bool {
        !Derivation().failingHere(expression, given: context.failing(of:)).failsNothing
    }

    // What a call hands in place at these positions, each variable held from
    // here on to what it reads as here: the callee holds the box as that type
    // while it runs, and a closure it makes may keep the box after it.
    private func heldInPlace(
        _ arguments: [Expression],
        at positions: [Int],
        in environment: [Name: Binding]
    ) -> Flow {
        var flow = Flow()

        for position in positions where arguments.indices.contains(position) {
            guard
                case let .reference(path) = arguments[position],
                let head = path.head,
                let taken = environment[head]?.takenType
            else { continue }

            flow.hold(taken, on: head)
        }

        return flow
    }

    // The positions of a call whose argument is not a value of what fills
    // its slot, where that names a type parameter of the body around.
    private func loose(
        taking: [LoweredType],
        readings sent: [LoweredType],
        shaped shapes: [Int: LiteralShape],
        filling filled: [Name: LoweredType],
        in loweredTypes: LoweredTypeTable
    ) -> [Int] {
        guard filled.values.contains(where: \.namesParameter) else { return [] }

        return taking.indices.filter { position in
            guard position < sent.count, taking[position].namesParameter else { return false }

            let written = LiteralShape(shapes[position], reading: sent[position])

            return !written.isHeld(by: taking[position], inPlace: true, in: loweredTypes)
        }
    }

    // The rules a call handing variables in place is held to, at each
    // position whose slot takes one: the argument is a path, the path's head
    // is a variable here, the path is one a write may take, and a variable a
    // closure or a call took goes to a slot of exactly the type it is held
    // to, since the callee is one more taker of the box. A call to a
    // declaration and a call of a value both come here with the slots they
    // hand to by position, each type parameter filled. That the variable is
    // the slot's own type is the slot's acceptance, read where each call kind
    // reads it. Two parameters handed paths under one head hold one box two
    // ways, and every write lands in it as it is made, so nothing here keeps
    // them apart.
    private func handedInPlace(
        _ arguments: [Expression],
        to slots: [LoweredType],
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws {
        guard case .judging = ask else { return }

        for (position, (slot, argument)) in zip(slots, arguments).enumerated() where slot.isInout {
            let at = place.child(.argument(position))

            guard case let .reference(path) = argument, let head = path.head else {
                try refuse(
                    "hands this argument in place, and what is handed in place"
                        + " is a variable's path. This argument is not one",
                    at: at,
                    when: ask
                )
                continue
            }

            guard let box = environment[head], box.isBox else {
                try refuse(
                    "hands '\(head)' in place, which is a fixed name here. A"
                        + " variable is handed in place",
                    at: at,
                    when: ask
                )
                continue
            }

            if case let .refused(reason) = writable(path, from: box, in: environment, with: context, at: at) {
                try refuse("hands '\(path.rendered)' in place, and \(reason)", at: at, when: ask)
            }

            if
                path.segments.count == 1,
                case let .held(held)? = environment[head]?.holding,
                slot.slotUnwrapped != held
            {
                try refuse(
                    "hands '\(head)' in place as \(slot.slotUnwrapped.rendered(in: context.loweredTypes)),"
                        + " and it is held as \(held.rendered(in: context.loweredTypes))",
                    at: at,
                    when: ask
                )
            }
        }
    }

    // What a name holds: what it declared, held against what was written into
    // it, or what the build worked out where it declared nothing.
    private func held(
        _ given: LoweredType,
        writing written: LiteralShape,
        declaredAs spelled: TypeExpression?,
        at place: Place,
        with context: TypingContext,
        when ask: Ask
    ) throws -> LoweredType {
        guard let declared = spelled?.lowered(in: context.loweredTypes) else { return given }

        guard written.isHeld(by: declared, inPlace: false, in: context.loweredTypes) else {
            try refuse(
                "holds \(declared.rendered(in: context.loweredTypes)), and what it was given is"
                    + " \(written.rendered(in: context.loweredTypes))",
                at: place,
                when: ask
            )

            // The probing ask has no refusal to throw, and what the name holds
            // is what it declared either way. Handing back what it was given
            // would leave the two walks reading one name as two types.
            return declared
        }

        guard case let .judging(_, fulfillment, _) = ask else { return declared }

        if let refusal = refusal(
            writing: written,
            to: declared,
            as: "holds",
            in: context.loweredTypes,
            fulfillment: fulfillment,
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }

        return declared
    }

    // The type a statement writes its value into, where it is known before
    // the value is read: what a name declares, or what a write reaches in a
    // box held to a type or through a path. A whole write a box takes as its
    // new type writes into none, and neither does a write the check refuses.
    private func writtenInto(
        by binding: Statement.Binding?,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> LoweredType? {
        switch binding {
        case let .constant(_, declared?)?, let .variable(_, declared?)?:
            return declared.lowered(in: context.loweredTypes)

        case let .assignment(path)?:
            guard let head = path.head, let box = environment[head] else { return nil }

            guard path.segments.count > 1 else { return box.heldType }

            guard case let .reaches(reached) = writable(path, from: box, in: environment, with: context, at: place) else {
                return nil
            }

            return reached

        default:
            return nil
        }
    }

    // A write that leaves the box reading as what it is held to, or as it
    // was through a path: refused where what is written does not fit what
    // the path reaches, a type parameter there taking only a value of it.
    // Answers the type the write was held to, or nil where it was refused.
    private func refuseUnfit(
        _ written: LiteralShape,
        writtenTo path: Path,
        into box: Binding,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws -> LoweredType? {
        let slot: LoweredType

        if path.segments.count == 1, let fixed = box.heldType {
            slot = fixed
        } else {
            switch writable(path, from: box, in: environment, with: context, at: place) {
            case let .refused(reason):
                try refuse(reason, at: place, when: ask)
                return nil

            case let .reaches(reached):
                slot = reached
            }
        }

        guard fits(written, into: slot, of: box, in: context.loweredTypes) else {
            try refuse(
                "writes '\(path.rendered)' as \(written.rendered(in: context.loweredTypes)), and it holds"
                    + " \(slot.rendered(in: context.loweredTypes))",
                at: place,
                when: ask
            )
            return nil
        }

        guard case let .judging(_, fulfillment, _) = ask else { return slot }

        if let refusal = refusal(
            writing: written,
            to: slot,
            as: "writes '\(path.rendered)' as",
            in: context.loweredTypes,
            fulfillment: fulfillment,
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }

        // A type parameter the body does not fill is one type it knows
        // nothing about, so a write there takes only a value of it.
        if slot.namesParameter, !written.isHeld(by: slot, inPlace: true, in: context.loweredTypes) {
            throw BuildError(
                "writes '\(path.rendered)' as \(written.rendered(in: context.loweredTypes)), where it reads"
                    + " \(slot.rendered(in: context.loweredTypes)): a type parameter the body does not fill"
                    + " takes only a value of it",
                at: place
            )
        }

        return slot
    }

    private func check(
        _ site: CallSite,
        against declared: Signature,
        with context: TypingContext,
        writing fulfillment: Fulfillment
    ) throws {
        let call = site.call
        let loweredTypes = context.loweredTypes
        let subject = "sending '\(call.selector)'"

        // A declaration with a type parameter in it is checked with the
        // parameter filled, or a slot standing for whatever arrives would
        // refuse whatever arrived. The judgement (a parameter read two ways has
        // no answer, a bounded one takes only what answers its bounds) is
        // the one every call surface shares, so this only gathers what the call
        // wrote into each slot.
        let slots: [Slot]

        switch instantiated(
            declared,
            over: context.slots(of: call.selector),
            answering: context.answer(of: call.selector),
            readings: site.readings,
            shaped: site.shapes,
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

        try check(
            call.arguments,
            reading: site.readings,
            shaped: site.shapes,
            against: slots.map(\.type),
            naming: slots,
            as: subject,
            in: loweredTypes,
            writing: fulfillment,
            at: site.place
        )
    }

    // A call hands exactly as many arguments as its callee takes, so another
    // count is refused before any position is read. Every judgement of a
    // call by position stands behind it: the walk asks it where the call
    // stands, ahead of what it reads in place there and before the call is
    // gathered for the gate, so the count is what an author is told first.
    private func refuseCount(handing handed: Int, taking count: Int, as subject: String, at place: Place) throws {
        guard handed != count else { return }

        throw BuildError("\(subject) with \(handed) arguments, and it takes \(count)", at: place.child(.arguments))
    }

    // Each argument held to what the callee takes at its position: the one
    // judgement a call to a declaration and a call of a value share, once
    // each has refused another count. What each position takes, then every
    // composition it mentions held to its bounds, with what leans on a claim
    // this table cannot settle written down for the link. What an argument holds is read
    // from the body it was written in, so a name bound to a call carries that
    // call's declared answer. A declaration's slots name each position; a
    // value's type writes the positions alone.
    private func check(
        _ arguments: [Expression],
        reading readings: [LoweredType],
        shaped shapes: [Int: LiteralShape],
        against types: [LoweredType],
        naming slots: [Slot]?,
        as subject: String,
        in loweredTypes: LoweredTypeTable,
        writing fulfillment: Fulfillment,
        at place: Place
    ) throws {
        for (position, (type, reading)) in zip(types, readings).enumerated() {
            let at = place.child(.argument(position))
            let given = LiteralShape(shapes[position], reading: reading)
            let slot = slots?[position]
            let named = slot.map { slot in "\(slot.name)" } ?? "argument \(position)"
            let quoted = slot.map { slot in "'\(slot.name)'" } ?? named

            guard given.isHeld(by: type, inPlace: false, in: loweredTypes) else {
                throw BuildError(
                    "\(subject) with \(named), which holds \(given.rendered(in: loweredTypes))"
                        + " where \(type.rendered(in: loweredTypes)) is declared",
                    at: at
                )
            }

            // A pair the link settles is written down at the call, which an
            // object records; a refusal here stands at the argument.
            if let refusal = refusal(
                writing: given,
                to: type,
                as: "\(quoted) holds",
                in: loweredTypes,
                fulfillment: fulfillment,
                at: place
            ) {
                throw BuildError("\(subject): \(refusal)", at: at)
            }
        }
    }
}
