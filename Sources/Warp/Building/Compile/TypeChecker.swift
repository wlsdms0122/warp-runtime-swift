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
// what it is.
//
// A dot on `Any` is held the same way: a dot needs a type to be judged
// against, so it refuses rather than deferring to the run. The author names
// the type with `as`, and the walk goes on from there.
//
// A path reads a name and nothing else. What each segment lands on is judged
// here against the type the walk reached, and a dot on a type that declares no
// such field is refused rather than left for the run. The walk that judges a
// path places it for the image: a field of a struct it proved at the field's
// place, a key written between brackets as the key type reads it.
struct TypeChecker {
    // What a call put in a generic declaration's type parameters, read once
    // by the walk: a parameter read two ways is refused rather than joined,
    // a bounded one is judged against its bounds, and the slots come back
    // with the readings filled.
    private enum Instantiation {
        case fits(slots: [Slot])
        case refusal(String)
    }

    // Where a path walk ended, a read's or a write's: what the whole of the
    // path holds, with the path as the walk placed it, or the refusal.
    private enum PathReading {
        case reads(LoweredType, placed: LoweredPath)
        case refused(String)
    }

    // The two asks the one walk answers. Judging is the compile's own pass
    // (every dot judged, every constant-headed path folded, every call
    // gathered, every refusal thrown) and it happens once per site. Probing
    // answers the type and flow questions alone and refuses nothing (what
    // cannot be read is `Any`) because its askers read a body out of place or
    // more than once: an operand typed where it stands, a round re-read until
    // its writes stop moving, where a refusal would be transient or repeated.
    private enum Ask {
        // Judging carries what folds a constant-headed path, where there is
        // one, and what the body being judged declares it answers, which a
        // literal it answers with is written into. Probing writes nothing.
        case judging(folding: Folding?, answering: LoweredType?)
        case probing

        // MARK: - Property
        // Whether this ask keeps what the walk rebuilds. Probing reads a body
        // out of place or more than once, so it hands the expression back as
        // written. A loop or a walk also asks this to choose between the final
        // probe and a judging re-walk, which carries refusals and gathered
        // sites.
        var rewrites: Bool {
            if case .judging = self { return true }

            return false
        }

        // What a `return` in the body being judged hands its answer to.
        var answer: LoweredType? {
            guard case let .judging(_, answering) = self else { return nil }

            return answering
        }

        // MARK: - Initializer
        // MARK: - Public
        // The same ask for a body that declares it answers `type`.
        func answering(_ type: LoweredType?) -> Ask {
            guard case let .judging(folding, _) = self else { return self }

            return .judging(folding: folding, answering: type)
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

        // What a list or map literal holds where it is written into a slot,
        // part by part, where its reading, joined across the parts, does not
        // say. A block holds what its result holds, and an attempt what each
        // of its two ways answers.
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
        folding: Folding?
    ) async throws -> (block: Block, calls: [CallSite], judgements: JudgementTable) {
        let promised = returns?.lowered(in: context.loweredTypes, bounds: context.bounds, sameTypes: context.sameTypes)

        // A closure literal the body answers, at any depth, is completed by
        // the type the declaration answers.
        let inner = try await inspected(
            block: promised.map { promised in promised.completing(block, in: context.loweredTypes) } ?? block,
            into: promised,
            at: place,
            in: environment,
            with: context,
            ask: .judging(folding: folding, answering: promised)
        )

        try refuseAnswers(
            written: LiteralShape(inner.literalShape, reading: inner.reading),
            answered: inner.flow.answered,
            to: promised,
            result: inner.block.result,
            at: place,
            in: context.loweredTypes
        )

        let written = promised.map { promised in promised.written(inner.block, in: context.loweredTypes) } ?? inner.block

        return (written, inner.calls, inner.judgements)
    }

    // The expression form, with what it was judged to hold. A constant's body
    // is one rather than a block, and a variable's start is written into
    // the type the variable declares and held to it, as a name's value is.
    func resolvedSites(
        in expression: Expression,
        into declared: LoweredType?,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        folding: Folding?
    ) async throws -> (Expression, [CallSite], JudgementTable, LiteralShape) {
        let ask = Ask.judging(folding: folding, answering: nil)
        let inner = try await inspected(
            expression,
            naming: nil,
            into: declared,
            at: place,
            in: environment,
            with: context,
            ask: ask
        )
        let written = LiteralShape(inner.literalShape, reading: inner.reading)

        _ = try held(inner.reading, writing: written, declaredAs: declared, at: place, with: context, when: ask)

        return (inner.rewritten, inner.calls, inner.judgements, written)
    }

    // A constant and a variable's start settle at the build, so what each is
    // written from is read rather than run. The same gate an operand passes:
    // an operand, a constant and a variable's start are where the build reads
    // an expression instead of running it.
    func refuseRunning(
        in expression: Expression,
        at place: Place,
        given context: TypingContext
    ) throws {
        try refuseRunning(
            expression,
            asOperand: place,
            given: context,
            when: .judging(folding: nil, answering: nil)
        )
    }

    // What a declaration answers when nobody wrote it down, read off its body
    // and kept beside the declaration, which the image carries as the author
    // wrote it. It reaches exactly as far as the readings do.
    //
    // A body's answer may be another body's, so the order is the call graph's. Each
    // declaration read after everything its answer could come from. Bodies that
    // reach one another's answers in a cycle, a recursive one included, are read
    // as `Any`: an answer worked out from itself is not one the text states.
    // Writing `returns` is what says more, and it removes the cycle by saying it.
    //
    // Every unwritten answer, read off its body, one at a time in the order the
    // call graph allows. Each handed back as it is worked out, and the context
    // asked for again, so the next body is read against it.
    //
    // Handed back one at a time: one answer changes one entry in each of the
    // build's tables a context is made of, and rebuilding them per declaration
    // copies the whole graph once per node.
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
                with: context().reading(only.symbol.procedure.signature)
            )

            // A reading naming a type parameter is handed on as it is. What a
            // parameter means is decided at the call, by the same filling a
            // declared `returns: some T` goes through, so a body answering its
            // own parameter answers what the caller put there, and a body
            // answering a type only it could name (what a walk *through* a
            // parameter reaches, named for the path that reached it) fills with
            // nothing, which is `Any`.
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
    func checked(_ calls: [CallSite], in context: TypingContext) throws {
        for call in calls {
            guard let signature = context.signature(of: call.call.selector) else {
                throw BuildError.unjudged(
                    "a call to '\(call.call.selector)', which names no declaration",
                    at: call.place
                )
            }

            try check(call, against: signature, with: context)
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
            into: nil,
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
    private func refuseAnswer(
        _ written: LiteralShape,
        to promised: LoweredType?,
        at place: Place,
        in table: LoweredTypeTable
    ) throws {
        guard let promised else { return }

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
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }
    }

    // A struct literal held to the declared struct its place reads: exactly
    // the declared fields, each holding what its field takes, and every
    // composition a field mentions held to its bounds.
    private func refuseFields(
        _ written: [Name: LiteralShape],
        of declared: LoweredStruct,
        named label: String,
        at place: Place,
        in table: LoweredTypeTable
    ) throws {
        let fits = Set(written.keys) == Set(declared.names)
            && declared.named.allSatisfy { name, field in
                written[name].map { shape in shape.isHeld(by: field.fieldUnwrapped, inPlace: false, in: table) } ?? false
            }

        guard fits else {
            let given = written.sorted { left, right in left.key < right.key }.map { name, shape in
                (name: name, spelled: shape.rendered(in: table))
            }
            let asked = declared.named.map { name, field in (name: name, spelled: field.rendered(in: table)) }

            throw BuildError(
                "a struct literal read as \(label) writes \(LoweredType.rendered(fields: given)),"
                    + " and \(label) declares \(LoweredType.rendered(fields: asked))",
                at: place
            )
        }

        for (name, field) in declared.named {
            guard let shape = written[name] else { continue }

            if let refusal = refusal(
                writing: shape,
                to: field.fieldUnwrapped,
                as: "'\(name)' holds",
                in: table,
                at: place
            ) {
                throw BuildError(refusal, at: place.child(.field(name)))
            }
        }
    }

    // Whether what a cast reads, read on its own, where nothing reads a
    // literal in it as a place does, is one of these types. A cast that is
    // the place a literal in it is read as says what nothing else does.
    // Asked only where judging has a refusal to state.
    private func readsAlone(
        _ value: Expression,
        as types: [LoweredType],
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        when ask: Ask
    ) async throws -> Bool {
        guard case .judging = ask else { return false }

        let alone = try await inspected(
            value,
            naming: nil,
            into: nil,
            at: place,
            in: environment,
            with: context,
            ask: .probing
        )

        return types.contains(alone.reading.asHeld)
    }

    // Why what is written into a slot is provably outside it, part by part
    // along `everyPart(along:)`, or nothing.
    private func refusal(
        writing written: LiteralShape,
        to declared: LoweredType,
        as label: String,
        in table: LoweredTypeTable,
        at place: Place
    ) -> String? {
        var found: String?

        _ = written.everyPart(along: declared, inPlace: false, in: table) { slot, part, _ in
            found = refusal(holding: part.folded, to: slot, as: label, in: table, at: place)

            return found == nil
        }

        return found
    }

    // Why what arrived is provably outside what a declaration holds it to,
    // wherever in the declaration a composition stands, or nothing.
    private func refusal(
        holding given: LoweredType,
        to declared: LoweredType,
        as label: String,
        in table: LoweredTypeTable,
        at place: Place
    ) -> String? {
        var unread = Substitution()
        var untaken = Substitution()
        var holding: [Substitution.Held] = []

        declared.binding(against: given, into: &unread, taking: &untaken, holding: &holding, in: table)

        for held in holding {
            for contract in held.bounds {
                if let refusal = table.refusal(
                    of: held.reading,
                    answering: contract,
                    orNull: held.orNull,
                    as: label
                ) {
                    return refusal
                }
            }
        }

        return nil
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

    private func instantiated(
        _ declared: Signature,
        over slots: [Slot],
        substitution: Substitution,
        shaped shapes: [Int: LiteralShape],
        in loweredTypes: LoweredTypeTable,
        at place: Place
    ) -> Instantiation {
        // A declaration with nothing to fill is read as the build lowered it.
        guard declared.isGeneric else { return .fits(slots: slots) }

        if let disagreement = substitution.disagreements(in: loweredTypes) {
            return .refusal(disagreement)
        }

        if let refused = substitution.associatedTypeRefusal(in: loweredTypes) {
            return .refusal(refused.reason)
        }

        let bounds = declared.bounds.sorted(by: { $0.key < $1.key })

        for (parameter, names) in bounds {
            if let refusal = substitution.unanswered(
                parameter,
                bounds: names,
                in: loweredTypes
            ) {
                return .refusal(refusal)
            }
        }

        // A derived associated type is one type, what fills its base gives,
        // so the values read at it do not make it several types.
        for (parameter, names) in bounds where !substitution.derived.contains(parameter) {
            if let refusal = substitution.severalTypes(
                of: parameter,
                bounds: names,
                over: slots.map(\.type),
                in: loweredTypes
            ) {
                return .refusal(refusal)
            }
        }

        // A list or map literal handed where a bounded parameter stands is
        // held to the bounds part by part, as one written into a slot
        // declaring them is: its join may answer them while a part does not.
        // Only what stands at such a parameter is asked here; `check` judges
        // the rest against what filled it. Each part is asked as the call
        // hands it on, a whole literal the filled slot reads as a fraction
        // being that fraction.
        for (position, written) in shapes.sorted(by: { $0.key < $1.key }) {
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
                at: place
            ) {
                return .refusal(refusal)
            }
        }

        return .fits(slots: slots.map { slot in Slot(name: slot.name, type: slot.type.filling(substitution.readings)) })
    }

    // Walking a path through types the way the resolver walks it through
    // values. Each dot is judged by the type the walk has reached: a type
    // with fields reads one, and a type without them has no name there to
    // read, which is refused.
    //
    // A field the type does not declare is refused, `?.` or not. The type
    // proved the absence, and a spelling that reads expected absence does not
    // overrule a proof. What may genuinely be absent at run is where a mark
    // speaks: a nullable's null, which the plain spelling is refused on, and
    // an entry a map may not hold, which `?[` answers null for. Either makes
    // the whole path's reading nullable.
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

        var walked: Path = [.name(head)]

        // The segments walked as the run reads them.
        var placed = LoweredPath([.name(head, optional: false)])

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

            // What the dot lands on, unwrapped: the walk-stopping types are
            // asked again after every unwrap, because what a `T?` holds is a
            // type like any other (`Any`, null, another name, another nullable)
            // and an unwrap that skipped the questions would judge on a type
            // nobody checked.
            unwrapping: while true {
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
                    case .name: "reads a dot on"
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
                if let reached = current.projecting(along: rest()) {
                    switch asWritten(rest(), in: environment, with: context, at: place) {
                    case let .refused(reason):
                        return .refused(reason)

                    case let .reads(_, standing):
                        return .reads(reached, placed: placed.appending(contentsOf: standing))
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

                    case let .reads(_, standing):
                        return .reads(.never, placed: placed.appending(contentsOf: standing))
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

                    case let .reads(_, standing):
                        return .reads(.null, placed: placed.appending(contentsOf: standing))
                    }
                }

                guard case let .nullable(inner) = current else { break unwrapping }

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
            // Asked of the segment, which owns the rule and the sentence, by
            // every landing, an entry's included.
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
            // element past the end is a defect at the run, not an absence, so
            // `?[` says nothing here unless it just unwrapped the array's own
            // null.
            func indexed(_ element: LoweredType) -> PathReading? {
                if let refusal = needless(.element) { return refusal }

                current = element

                return nil
            }

            switch (segment, current) {
            // Brackets on a list read an element at a position: a whole
            // number written there, or a name the run reads, which is a path
            // of its own judged like one. The walk goes on with the element
            // type either way.
            case let (.indexRef(inner, optionally), .array(element)):
                let judged = indexReference(inner, in: environment, with: context, at: place)

                guard case let .reads(_, standing) = judged else { return judged }

                if let refused = indexed(element) { return refused }

                placed.append(.at(standing, optional: optionally))

            case let (.index(index, optionally), .array(element)):
                if let refusal = position(index, at: walked, in: context.loweredTypes) {
                    return .refused(refusal)
                }

                if let refused = indexed(element) { return refused }

                placed.append(.index(index, optional: optionally))

            // Brackets on a map read the entry under a key of its key type,
            // written there or read by the run. A key written there is a
            // literal, written into the key type as any literal is into its
            // place. Which keys are there is the run's fact, so absence
            // follows the mark, the rule every entry reading shares.
            case let (.indexRef(inner, optionally), .dictionary(key, entry)):
                let judged = keyReference(inner, keyedBy: key, in: environment, with: context, at: place)

                guard case let .reads(_, standing) = judged else { return judged }

                if let refusal = needless(.entry) { return refusal }

                if optionally { optional = true }

                current = entry
                placed.append(.at(standing, optional: optionally))

            case let (.index(index, optionally), .dictionary(key, entry)):
                if let refusal = written(key: index, keyedBy: key, at: walked, in: context.loweredTypes) {
                    return .refused(refusal)
                }

                if let refusal = needless(.entry) { return refusal }

                if optionally { optional = true }

                current = entry
                placed.append(.index(key.written(index, in: context.loweredTypes), optional: optionally))

            case (.index, _), (.indexRef, _):
                return .refused(
                    "\(walked.rendered) indexes into \(current.rendered(in: context.loweredTypes)),"
                        + " and brackets read a list by a position and a map by a key"
                )

            // A dot on a struct reads the field it declares. A field it does
            // not declare is a defect the text shows, refused here rather than
            // found at run, and so is a `?.` on one it does declare: the type
            // proves the field is there, so the spelling that expects absence
            // says nothing, unless it just read past the struct's own null.
            case let (.name(key, optionally), .struct(fields)):
                guard let position = fields.position(of: key) else {
                    return .refused(
                        "\(walked.rendered) names '\(key)',"
                            + " which \(current.rendered(in: context.loweredTypes)) does not declare."
                            + " A procedure is sent with a written call, and data"
                            + " past the declaration is read by declaring it"
                    )
                }

                if let refusal = needless(.field(key)) { return refusal }

                current = fields.fields[position].fieldUnwrapped
                placed.append(.field(position, key, optional: optionally))

            // A type with no fields, a map among them, has no name here to
            // read. The procedure by this spelling is sent with a written
            // call, which names the declaration it means, and what a list or
            // a map holds is read through brackets.
            case let (.name(key, _), _):
                return .refused(
                    "\(walked.rendered) names '\(key)',"
                        + " and \(current.rendered(in: context.loweredTypes)) has no name there to read."
                        + " A procedure by that spelling is sent with a written call,"
                        + " and what a list or a map holds is read through brackets"
                )
            }
        }

        return .reads(optional ? current.admittingNull : current, placed: placed)
    }

    // The inner index paths a fold can settle. `items[C]` reads its index from
    // a constant, so the index is knowable now and no constant name survives
    // into the image. Recursive, because an index path holds index paths of its
    // own (`items[names[C]]`) and the promise is about all of them.
    private func foldedIndexReferences(
        _ path: LoweredPath,
        at place: Place,
        folding: Folding
    ) async throws -> LoweredPath {
        var folded = LoweredPath([])

        for segment in path.segments {
            folded.append(try await self.folded(segment, at: place, folding: folding))
        }

        return folded
    }

    // What a path write reaches from the box its head names, or why it may
    // not. Each field on the way is one its declared struct wrote `var`; an
    // element or an entry is written through brackets. A type that may be
    // null is not written into, and neither is `Any`.
    private func writable(
        _ path: Path,
        from box: Binding,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        if let refusal = path.writtenThroughAbsence {
            return .refused(refusal)
        }

        var current = box.type
        var walked = Path(Array(path.segments.prefix(1)))
        var placed = LoweredPath(path.head.map { head in [.name(head, optional: false)] } ?? [])

        for segment in path.segments.dropFirst() {
            walked.append(segment)

            current = context.resolve(current)

            switch (segment, current) {
            case let (.name(key, optionally), .struct(fields)):
                guard let position = fields.position(of: key) else {
                    return .refused(
                        "\(walked.rendered) names '\(key)', which \(current.rendered(in: context.loweredTypes))"
                            + " does not declare"
                    )
                }

                let field = fields.fields[position]

                if !field.isVariable {
                    return .refused(
                        "\(walked.rendered) writes through '\(key)', which the type"
                            + " declares without `var`. A field a path may write"
                            + " through is declared `var`"
                    )
                }

                current = field.fieldUnwrapped
                placed.append(.field(position, key, optional: optionally))

            // What stands between the brackets is judged as a read's is: a
            // position in a list and a key in a map.
            case let (.indexRef(inner, optionally), .dictionary(key, entry)):
                switch keyReference(inner, keyedBy: key, in: environment, with: context, at: place) {
                case let .refused(reason):
                    return .refused(reason)

                case let .reads(_, standing):
                    current = entry
                    placed.append(.at(standing, optional: optionally))
                }

            case let (.index(index, optionally), .dictionary(key, entry)):
                if let refusal = written(key: index, keyedBy: key, at: walked, in: context.loweredTypes) {
                    return .refused(refusal)
                }

                current = entry
                placed.append(.index(key.written(index, in: context.loweredTypes), optional: optionally))

            case let (.indexRef(inner, optionally), .array(element)):
                switch indexReference(inner, in: environment, with: context, at: place) {
                case let .refused(reason):
                    return .refused(reason)

                case let .reads(_, standing):
                    current = element
                    placed.append(.at(standing, optional: optionally))
                }

            case let (.index(index, optionally), .array(element)):
                if let refusal = position(index, at: walked, in: context.loweredTypes) {
                    return .refused(refusal)
                }

                current = element
                placed.append(.index(index, optional: optionally))

            case (.name, .any), (.index, .any), (.indexRef, .any):
                return .refused(
                    "\(walked.rendered) writes into \(current.rendered(in: context.loweredTypes)), which"
                        + " declares nothing. A type is written by naming it"
                )

            case (.name, .nullable), (.index, .nullable), (.indexRef, .nullable):
                return .refused(
                    "\(walked.rendered) writes into \(current.rendered(in: context.loweredTypes)), which may"
                        + " be null. Write the whole first"
                )

            case (.name, _):
                return .refused(
                    "\(walked.rendered) writes a field into \(current.rendered(in: context.loweredTypes)),"
                        + " which has none"
                )

            case (.index, _), (.indexRef, _):
                return .refused(
                    "\(walked.rendered) writes through brackets into \(current.rendered(in: context.loweredTypes)),"
                        + " and brackets write a list by a position and a map by a key"
                )
            }
        }

        return .reads(current, placed: placed)
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
        case .literal, .reference, .closure, .apply, .conditional, .loop, .attempt, .leave:
            return nil

        case let .cast(value, _, _):
            return runs(in: value, given: context)

        case let .array(array):
            return array.lazy.compactMap { element in runs(in: element, given: context) }.first

        case let .struct(literal):
            return literal.values.lazy.compactMap { field in runs(in: field, given: context) }.first

        case let .dictionary(entries):
            return entries.lazy.compactMap { entry in
                runs(in: entry.key, given: context) ?? runs(in: entry.value, given: context)
            }.first

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
    private func refuseAnswers(
        written answer: LiteralShape,
        answered: [Flow.Answer],
        to promised: LoweredType?,
        result: Expression?,
        at place: Place,
        in table: LoweredTypeTable
    ) throws {
        for one in answered {
            try refuseAnswer(
                LiteralShape(one.literalShape, reading: one.reading),
                to: promised,
                at: one.place,
                in: table
            )
        }

        try refuseAnswer(
            answer,
            to: promised,
            at: place.part(result != nil ? .result : .returns),
            in: table
        )
    }

    // What a call puts in the type parameters a declaration names: what the
    // arguments read each as, and each associated type of one as what fills
    // its parameter gives under its name, one of a parameter of the
    // procedure being read as that procedure reads it.
    private func filling(
        _ signature: Signature?,
        over slots: [Slot],
        against readings: [LoweredType],
        with context: TypingContext
    ) -> Substitution {
        var substitution = Substitution(filling: slots.map(\.type), against: readings, in: context.loweredTypes)

        guard let signature, !signature.associatedTypes.isEmpty else { return substitution }

        substitution.derive(
            signature.associatedTypes,
            bounds: signature.bounds,
            said: signature.loweredSameTypes(in: context.loweredTypes),
            reading: context.associatedTypes,
            in: context.loweredTypes
        )

        return substitution
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
    // walk stops. What they reach is not read, so what the reference reads
    // is judged by the run against what arrived, a position or a key.
    private func asWritten(
        _ path: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        var placed = LoweredPath([])

        for segment in path.segments {
            switch segment {
            case let .name(name, optional):
                placed.append(.name(name, optional: optional))

            case let .index(index, optional):
                placed.append(.index(index, optional: optional))

            case let .indexRef(inner, optional):
                switch reading(of: inner, in: environment, with: context, at: place) {
                case let .refused(reason):
                    return .refused(reason)

                case let .reads(_, standing):
                    placed.append(.at(standing, optional: optional))
                }
            }
        }

        return .reads(.any, placed: placed)
    }

    // The one machine that judges an index reference on a list, answering
    // the refusal or what the inner path reads. The inner path is a path of
    // its own, and what it reads stands where an `Int` is read.
    private func indexReference(
        _ inner: Path,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        let judged = reading(of: inner, in: environment, with: context, at: place)

        guard
            case let .reads(innerType, _) = judged,
            !LoweredType.int.accepts(innerType, in: context.loweredTypes)
        else {
            return judged
        }

        return .refused(
            "index reference \(inner.rendered) reads"
                + " \(innerType.rendered(in: context.loweredTypes)), expected Int"
        )
    }

    // The one machine that judges a key the run reads, answering the
    // refusal or what the inner path reads. What stands between the
    // brackets on a map stands where its key type is read.
    private func keyReference(
        _ inner: Path,
        keyedBy key: LoweredType,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place
    ) -> PathReading {
        let judged = reading(of: inner, in: environment, with: context, at: place)

        guard
            case let .reads(innerType, _) = judged,
            !key.accepts(innerType, in: context.loweredTypes)
        else {
            return judged
        }

        return .refused(
            "key reference \(inner.rendered) reads"
                + " \(innerType.rendered(in: context.loweredTypes)),"
                + " expected \(key.rendered(in: context.loweredTypes))"
        )
    }

    // A key written or settled between the brackets, judged the way a key
    // the run reads is: it stands where the map's key type is read, as a
    // literal written there is read.
    private func written(
        key: Value,
        keyedBy keyType: LoweredType,
        at walked: Path,
        in table: LoweredTypeTable
    ) -> String? {
        let reading = LoweredType(literal: key, in: table)

        guard !keyType.accepts(reading, in: table) else { return nil }

        return "\(walked.rendered) reads its key as \(reading.rendered(in: table)),"
            + " expected \(keyType.rendered(in: table))"
    }

    // A position written or settled between the brackets: a whole number,
    // and one below zero is no position.
    private func position(_ index: Value, at walked: Path, in table: LoweredTypeTable) -> String? {
        guard case let .int(position) = index else {
            return "\(walked.rendered) reads its index as"
                + " \(LoweredType(of: index, in: table).rendered(in: table)), expected Int"
        }

        guard position < 0 else { return nil }

        return "\(walked.rendered) indexes a list at \(position), and a whole number below zero is no position"
    }

    // One index path a fold settles. The recursion of the gathering above,
    // written out because reading a constant runs, and what runs is a call.
    private func folded(
        _ segment: LoweredPath.Segment,
        at place: Place,
        folding: Folding
    ) async throws -> LoweredPath.Segment {
        guard case let .at(written, optionally) = segment else { return segment }

        // An index path indexed in turn by what only the run reads stays a
        // path however it is headed: the run reads it.
        let inner = try await foldedIndexReferences(written, at: place, folding: folding)

        guard let head = folding.boundHead(of: inner) else {
            return .at(inner, optional: optionally)
        }

        // The mark rides the fold: which element or entry is read settles
        // now, whether the list or the map is there to be read stays the
        // run's question. Whether the value stands as a position or a key is
        // judged where the folded path is.
        do {
            return .index(try await folding.read(inner, at: place), optional: optionally)
        } catch {
            throw BuildError("reading constant '\(head)': \(error)", at: place)
        }
    }

    // The gate a refusal passes: judging throws it, and the probing ask has
    // none to throw. A refusal the walk states passes here, so it cannot forget
    // which ask refuses, and what remains after it under probing is the
    // degraded answer beside each call. The constant-folding throws do not
    // pass here: a folding scope rides only the judging ask.
    private func refuse(
        _ reason: @autoclosure () -> String,
        at place: Place,
        when ask: Ask
    ) throws {
        guard case .judging = ask else { return }

        throw BuildError(reason(), at: place)
    }

    // Whether a struct literal stands here as itself or as a part of a list
    // or a map literal, where the place it is written into decides which
    // struct it is.
    private func holdsStructLiteral(_ expression: Expression) -> Bool {
        switch expression {
        case .struct:
            return true

        case let .array(items):
            return items.contains { item in holdsStructLiteral(item) }

        case let .dictionary(entries):
            return entries.contains { entry in holdsStructLiteral(entry.key) || holdsStructLiteral(entry.value) }

        default:
            return false
        }
    }

    // An operand is data: the run reads it rather than running it. A call to a
    // declaration that answers only by running is refused here, where the
    // operand is written, rather than found when the reading reaches it.
    private func refuseRunning(
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
    private func refuseCondition(
        _ reading: LoweredType,
        at place: Place,
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
    // failure. `declared` is the type of the place the expression is written
    // into, where one is: a struct literal is read as the declared struct
    // it reads, and nil writes it into none.
    private func inspected(
        _ expression: Expression,
        naming name: Name?,
        into declared: LoweredType?,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> Inspection {
        switch expression {
        // A list or a map written out as a value is a literal the way one
        // written part by part is, each element, key and value a literal of
        // its own, so it is judged as that one.
        case let .literal(.array(elements)):
            return try await inspected(
                .array(elements.map(Expression.literal)),
                naming: name,
                into: declared,
                at: place,
                in: environment,
                with: context,
                ask: ask
            )

        case let .literal(.dictionary(dictionary)):
            return try await inspected(
                .dictionary(dictionary.entries.map { entry in (key: .literal(entry.key), value: .literal(entry.value)) }),
                naming: name,
                into: declared,
                at: place,
                in: environment,
                with: context,
                ask: ask
            )

        case let .literal(value):
            return Inspection(
                rewritten: expression,
                reading: LoweredType(literal: value, in: context.loweredTypes)
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
                into: answer,
                at: place.child(.held),
                in: environment,
                with: context,
                ask: ask
            )

            let handed = answer.map { answer in answer.written(carried.rewritten, in: context.loweredTypes) } ?? carried.rewritten

            return Inspection(
                rewritten: ask.rewrites
                    ? .leave(
                        Leave(reach: leave.reach, target: leave.target, value: handed)
                    )
                    : expression,
                calls: carried.calls,
                judgements: carried.judgements,
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

            case let .reads(read, placed):
                guard case let .judging(folding, _) = ask else {
                    return Inspection(rewritten: expression, reading: read, flow: reached)
                }

                // What stays a path reaches the lowering as it was placed.
                func reference(_ placed: LoweredPath) -> Inspection {
                    var judgements = JudgementTable()

                    judgements.record(.reference(placed), at: place)

                    return Inspection(
                        rewritten: .reference(placed.path),
                        judgements: judgements,
                        reading: read,
                        flow: reached
                    )
                }

                guard let folding else { return reference(placed) }

                // An inner index path may read a constant too. `items[C]` folds
                // its index the way a whole constant path folds, so no constant
                // name survives into the image. One indexed by what only the run
                // reads (`digits[ch]`) cannot fold: it stays a path, and the
                // lowering binds the constant in the body for the run to read.
                let folded = try await foldedIndexReferences(placed, at: place, folding: folding)

                // What an index settled to stands as if it were written there,
                // and is judged as such.
                if
                    folded != placed,
                    case let .refused(reason) = reading(of: folded.path, in: environment, with: context, at: place)
                {
                    throw BuildError(reason, at: place)
                }

                guard let head = folding.boundHead(of: folded) else { return reference(folded) }

                do {
                    let value = try await folding.read(folded, at: place)

                    return Inspection(rewritten: .literal(value), reading: read, flow: reached)
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
            var declaredElement: LoweredType?

            if case let .array(held)? = declared?.literalPlace {
                declaredElement = held
            }

            for (position, member) in array.enumerated() {
                let inner = try await inspected(
                    member,
                    naming: nil,
                    into: declaredElement,
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
            // The type the cast names is a place a literal in what it reads
            // is written into, as a slot is: a struct literal is read as the
            // struct it names, a whole literal as the fraction it names where
            // it declares a Double, and a closure literal is completed by the
            // procedure type it names, at every depth.
            let claim = type.lowered(in: context.loweredTypes)
            let inner = try await inspected(
                claim.completing(value, in: context.loweredTypes),
                naming: nil,
                into: claim,
                at: place.child(.subject(optional: optional)),
                in: environment,
                with: context,
                ask: ask
            )
            let read = claim.written(inner.reading, in: context.loweredTypes).asHeld

            // Both refusals ask the types themselves, whether or not the
            // reading is fully proven.
            //
            // Needless means the claim and the reading are the same type, not
            // that one would accept the other. `accepts` holds between `Int?`
            // and `Int`, and a reading of `Int?` cast to `Int` still says
            // something the run has to answer.
            //
            // The claim is judged first, and on itself: a cast onto a type
            // that proves nothing opens nothing, whatever it was written over.
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
                // it is, so `as` would fail and `as?` answer null on every
                // run, and the build refuses it.
                try refuse(
                    "reads \(read.rendered(in: context.loweredTypes)) as \(claim.rendered(in: context.loweredTypes)),"
                        + " and no value is both."
                        + " A cast names a type the value may turn out to"
                        + " have, and this one it never can",
                    at: place,
                    when: ask
                )
            } else if claim == read || handed == read, try await readsAlone(
                value,
                as: [claim, handed],
                at: place.child(.subject(optional: optional)),
                in: environment,
                with: context,
                when: ask
            ) {
                // Asked of the reading this hands on, not of the spelling that
                // made it. `payload as? Int` hands on `Int?` and `payload as?
                // Maybe` hands on `Maybe`: the same type by two spellings, so
                // the question is the type's.
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

            if failsHere(expression, in: environment, given: context) {
                flow.fail()
            }

            return Inspection(
                // The author's spelling stands, so a document written back
                // out keeps the declaration it leaned on.
                rewritten: ask.rewrites
                    ? .cast(claim.written(inner.rewritten, in: context.loweredTypes), as: type, optional: optional)
                    : expression,
                calls: inner.calls,
                judgements: inner.judgements,
                // `?` is asked of the fact: a type that already holds null is
                // not wrapped again.
                reading: handed,
                flow: flow
            )

        // In the order written, each key before its value: the order the run
        // makes the entries in. The keys join to one type and the values to
        // another, the way a list's elements do, and an empty map holds
        // `Never` at both, so it is a value of a map of any types. What the
        // keys join to keys the map type the literal reads as, so it answers
        // `Hashable` as a written key does; where the place declares a map,
        // each key was held to the key it declares.
        case let .dictionary(entries):
            var environment = environment
            var rewritten: [(key: Expression, value: Expression)] = []
            var calls: [CallSite] = []
            var judgements = JudgementTable()
            var flowed = Flow()
            var keys: LoweredType = .never
            var values: LoweredType = .never
            var shapes: [(key: LiteralShape, value: LiteralShape)] = []
            var declaredParts: (key: LoweredType?, value: LoweredType?) = (nil, nil)

            if case let .dictionary(key, value)? = declared?.literalPlace {
                declaredParts = (key, value)
            }

            for (position, entry) in entries.enumerated() {
                var parts: [Inspection] = []

                for (part, child, into) in [
                    (entry.key, Expression.Child.entryKey(position), declaredParts.key),
                    (entry.value, .entryValue(position), declaredParts.value)
                ] {
                    let inner = try await inspected(
                        part,
                        naming: nil,
                        into: into,
                        at: place.child(child),
                        in: environment,
                        with: context,
                        ask: ask
                    )

                    inner.flow.apply(to: &environment)
                    flowed = flowed.followed(by: inner.flow)
                    calls += inner.calls
                    judgements.absorb(inner.judgements)
                    parts.append(inner)
                }

                keys = keys.joined(parts[0].reading)
                values = values.joined(parts[1].reading)
                shapes.append((key: parts[0].written, value: parts[1].written))
                rewritten.append((key: parts[0].rewritten, value: parts[1].rewritten))
            }

            if declaredParts.key == nil, let refusal = context.loweredTypes.keyRefusal(of: keys) {
                try refuse(refusal, at: place, when: ask)
            }

            // A literal whole number read beside fractions is the fraction it
            // names, since the keys hold one type and the values another.
            if ask.rewrites {
                rewritten = rewritten.map { entry in
                    (key: keys.written(entry.key, in: context.loweredTypes), value: values.written(entry.value, in: context.loweredTypes))
                }
            }

            return Inspection(
                rewritten: ask.rewrites ? .dictionary(rewritten) : expression,
                calls: calls,
                judgements: judgements,
                reading: .dictionary(key: keys, value: values),
                flow: flowed,
                literalShape: .map(shapes)
            )

        // A struct literal is the declared struct the place it is written
        // into reads, judged there field by field, exactly the declared
        // fields, and built under the struct's name. Its fields are read in
        // name order, the order the run evaluates them in, so what one
        // field's write means to the next is the same fact at the run.
        //
        // A struct taking type parameters is read as applied to what its
        // place applies it to, and where the place leaves one to a call, to
        // what its fields read the parameter as.
        case let .struct(literal):
            let row = declared?.row
            let applied = declared?.arguments ?? []
            var held: LoweredStruct?

            if let row, case let .struct(fields) = context.loweredTypes.declared(row, applied: applied) {
                held = fields
            } else {
                try refuse(
                    "a struct literal is written where a declared struct is read, and nothing here declares one",
                    at: place,
                    when: ask
                )
            }

            var environment = environment
            var rewritten: [Name: Expression] = [:]
            var calls: [CallSite] = []
            var judgements = JudgementTable()
            var flowed = Flow()
            var shapes: [Name: LiteralShape] = [:]
            var readings: [Name: LoweredType] = [:]

            for (name, field) in literal.sorted(by: { $0.key < $1.key }) {
                let inner = try await inspected(
                    field,
                    naming: nil,
                    into: held?[name]?.fieldUnwrapped,
                    at: place.child(.field(name)),
                    in: environment,
                    with: context,
                    ask: ask
                )

                inner.flow.apply(to: &environment)
                flowed = flowed.followed(by: inner.flow)
                calls += inner.calls
                judgements.absorb(inner.judgements)
                shapes[name] = inner.written
                readings[name] = inner.written.folded
                rewritten[name] = inner.rewritten
            }

            // Read where no declared struct is, it holds no value the build
            // can name, and a call reading it at a type parameter reads it
            // again once the other arguments have filled it.
            guard let row, let held else {
                return Inspection(
                    rewritten: ask.rewrites ? .struct(rewritten) : expression,
                    calls: calls,
                    judgements: judgements,
                    reading: .never,
                    flow: flowed
                )
            }

            let label = context.loweredTypes.labels[row]
            let read = context.loweredTypes.arguments(of: row, filling: readings)
            let reading = LoweredType.named(
                row,
                arguments: zip(applied, read).map { written, read in written.namesParameter ? read : written }
            )

            if case .judging = ask {
                try refuseFields(
                    shapes,
                    of: held,
                    named: LoweredType.named(row, arguments: applied).rendered(in: context.loweredTypes),
                    at: place,
                    in: context.loweredTypes
                )
            }

            judgements.record(label, ofStructAt: place)

            return Inspection(
                rewritten: ask.rewrites ? .struct(rewritten) : expression,
                calls: calls,
                judgements: judgements,
                reading: reading,
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
        case let .closure(written):
            // The Validator refuses a closure literal that is not a body.
            guard case let .body(block) = written.implementation else {
                assertionFailure("a closure literal reached the type check without a body")

                return Inspection(rewritten: expression, reading: .any)
            }

            // A closure's `some T` is the name the procedure around it filled,
            // held to the bounds that procedure declared; its own signature
            // writes none.
            var procedure = written.with(
                signature: written.signature.bounded(by: context.bounds, sameTypes: context.sameTypes)
            )
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
            // and is held to it, and leaves the box reading it.
            let taken = outside.mapValues { binding in
                binding.taken(to: binding.type)
            }

            // The body read under the ask this walk answers: what it reaches
            // from outside is what the closure takes, which either ask needs.
            // A closure literal the body answers, at any depth, is completed
            // by the type the closure answers. Its body reads the names of
            // the procedure around it, so a closure it writes does too.
            let promised = procedure.signature.loweredReturns(in: context.loweredTypes)
            let inner = try await inspected(
                block: promised.map { promised in promised.completing(block, in: context.loweredTypes) } ?? block,
                into: promised,
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
                    signature: Signature(
                        parameters: procedure.signature.parameters,
                        returns: answered.spelled(in: context.loweredTypes)
                    )
                    .bounded(by: context.bounds, sameTypes: context.sameTypes)
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

            if case .judging = ask {
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
                        at: place.child(.closure)
                    ) {
                        throw BuildError(refusal, at: place.child(.closure))
                    }
                }

                try refuseAnswers(
                    written: LiteralShape(inner.literalShape, reading: inner.reading),
                    answered: inner.flow.answered,
                    to: promised,
                    result: inner.block.result,
                    at: place.child(.closure),
                    in: context.loweredTypes
                )

                body = promised.map { promised in promised.written(inner.block, in: context.loweredTypes) } ?? inner.block
                calls = inner.calls
                judgements = inner.judgements
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
            let failing = Derivation().failing(
                body,
                given: context.failing(of:),
                bound: bound,
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
                        failing: failing
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
                    procedure.signature.type.with(failing: failing),
                    const ? .const : .unstated,
                    isolated ? .isolated : .unstated
                )
                .lowered(
                    in: context.loweredTypes,
                    bounds: procedure.signature.bounds,
                    sameTypes: procedure.signature.sameTypes
                ),
                flow: flow
            )

        // Which value is called is decided at the run, and what it answers is
        // the slot's to say under either ask: a procedure type that wrote
        // `returns` answers that, and one that wrote none opens to `Any`. Its
        // operands are data, held as operands below, and write nothing. What
        // the call carries out is the boxes it took: a variable it hands in
        // place, and what a closure among its operands took.
        case let .apply(callee, arguments):
            // One by one, because a loop over the values alone reports the
            // third operand from the place the first was.
            if case .judging = ask {
                try refuseRunning(callee, asOperand: place.child(.callee), given: context, when: ask)

                for (position, argument) in arguments.enumerated() {
                    try refuseRunning(argument, asOperand: place.child(.argument(position)), given: context, when: ask)
                }
            }

            let called = try await inspected(
                callee,
                naming: nil,
                into: nil,
                at: place.child(.callee),
                in: environment,
                with: context,
                ask: ask
            )

            // Read once, and every judgement below asks this reading: whether
            // it could be called, what it takes and what it answers.
            let callee = called.reading.slotUnwrapped
            let answers: LoweredType

            if case let .procedure(signature?, _, _) = callee, let returns = signature.returns {
                answers = returns
            } else {
                answers = .any
            }

            // What the callee's type takes at each position, where it says,
            // which is the place each argument is written into.
            let taken: [LoweredType?] = arguments.indices.map { position in
                guard case let .procedure(signature?, _, _) = callee, signature.parameters.indices.contains(position) else {
                    return nil
                }

                return signature.parameters[position]
            }

            // A closure literal written here, at any depth, is completed by
            // the type it is written into.
            let arguments = zip(arguments, taken).map { argument, slot in
                slot.map { slot in slot.completing(argument, in: context.loweredTypes) } ?? argument
            }

            // The positions the call hands a variable in place: the ones the
            // slot's type marks `inout`, where the build reads its parameters,
            // and none where it does not.
            var handed: [Int] = []

            if case let .procedure(signature?, _, _) = callee {
                handed = signature.parameters.indices.filter { position in signature.parameters[position].isInout }
            }

            // What the operands took is taken by the call, and so is what it
            // hands in place.
            var flow = heldInPlace(arguments, at: handed, in: environment)

            flow = flow.followed(by: called.flow)

            guard case .judging = ask else {
                for (position, argument) in arguments.enumerated() {
                    flow = flow.followed(by: try await inspected(
                        argument,
                        naming: nil,
                        into: taken[position],
                        at: place.child(.argument(position)),
                        in: environment,
                        with: context,
                        ask: ask
                    ).flow)
                }

                if failsHere(expression, in: environment, given: context) {
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

            guard callee.couldBeProcedure else {
                throw BuildError(
                    "calls a value of \(called.reading.rendered(in: context.loweredTypes)),"
                        + " and only a procedure can be called",
                    at: place.child(.callee)
                )
            }

            // A value whose type writes no parameters says nothing the build
            // can hold an argument against, so it is called once a cast says
            // what procedure it is.
            guard case let .procedure(signature?, _, _) = callee else {
                throw BuildError(
                    "calls a value of \(called.reading.rendered(in: context.loweredTypes)),"
                        + " which writes no parameters it takes. A cast says what procedure it is",
                    at: place.child(.callee)
                )
            }

            let parameters = signature.parameters
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
                    into: parameters[position],
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
            // literal is read as the slot reads it.
            rewritten = zip(rewritten, parameters).map { argument, slot in slot.written(argument, in: context.loweredTypes) }

            try handedInPlace(arguments, to: parameters, in: environment, with: context, at: place, when: ask)

            // A type parameter the slot names is the body's own, which no
            // call fills.
            for (position, slot) in parameters.enumerated() {
                let written = LiteralShape(shapes[position], reading: sent[position])

                try refuseUnfilled(
                    written,
                    at: slot,
                    as: "\(subject) with \(written.rendered(in: context.loweredTypes)) at position \(position)",
                    in: context.loweredTypes,
                    at: place.child(.argument(position)),
                    when: ask
                )
            }

            try check(
                reading: sent,
                shaped: shapes,
                against: parameters,
                naming: nil,
                as: subject,
                in: context.loweredTypes,
                at: place
            )

            judgements.record(.apply(inPlace: handed), at: place)

            if failsHere(expression, in: environment, given: context) {
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
            let mayFail = failsHere(expression, in: environment, given: context)
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
                        into: slots.indices.contains(position) ? slots[position].type : nil,
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
                        filling: filling(signature, over: slots, against: readings, with: context).readings
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
                try refuseRunning(argument, asOperand: argumentPlaces[position], given: context, when: ask)
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

            // A closure literal written here, at any depth, is completed by
            // the type it is written into.
            let written = call.arguments.indices.map { position in
                slots[position].type.completing(call.arguments[position], in: context.loweredTypes)
            }

            // A struct literal at a type parameter is the declared struct the
            // other arguments fill it with, so an argument holding one is read
            // once the readings join. Until then it holds no value of its
            // own and fills nothing, and what it reads as there is what it
            // fills the call with.
            let waiting = Set(call.arguments.indices.filter { position in
                slots[position].type.namesParameter && holdsStructLiteral(written[position])
            })
            var inspections: [Int: Inspection] = [:]
            var sent: [LoweredType] = []

            for position in call.arguments.indices {
                let inner = try await inspected(
                    written[position],
                    naming: nil,
                    into: slots[position].type,
                    at: argumentPlaces[position],
                    in: environment,
                    with: context,
                    ask: waiting.contains(position) ? .probing : ask
                )

                inspections[position] = waiting.contains(position) ? nil : inner
                sent.append(inner.written.folded)
            }

            // The one filling of the call, which its site judges: its answer
            // and every slot an argument is read into come from it.
            let substitution = filling(signature, over: slots, against: sent, with: context)
            let taking = slots.map { slot in slot.type.filling(substitution.readings) }

            // A parameter read two ways fills nothing a literal could be read
            // as, so the call is refused for it before a literal is read.
            if !waiting.isEmpty, let disagreement = substitution.disagreements(in: context.loweredTypes) {
                throw BuildError("sending '\(call.selector)': \(disagreement)", at: place)
            }

            for position in waiting.sorted() {
                inspections[position] = try await inspected(
                    written[position],
                    naming: nil,
                    into: taking[position],
                    at: argumentPlaces[position],
                    in: environment,
                    with: context,
                    ask: ask
                )
            }

            var arguments: [Expression] = []
            var shapes: [Int: LiteralShape] = [:]
            var calls: [CallSite] = []
            var judgements = JudgementTable()

            for position in call.arguments.indices {
                guard let inner = inspections[position] else { continue }

                arguments.append(inner.rewritten)
                shapes[position] = inner.literalShape
                calls += inner.calls
                judgements.absorb(inner.judgements)
                flow = flow.followed(by: inner.flow)
            }

            try handedInPlace(
                call.arguments,
                to: taking,
                in: environment,
                with: context,
                at: place,
                when: ask
            )

            // A slot the body's own type parameter fills stands for whatever
            // filled the body's.
            for (position, slot) in taking.enumerated() {
                try refuseUnfilled(
                    LiteralShape(shapes[position], reading: sent[position]),
                    at: slot,
                    as: "sending '\(call.selector)' with \(sent[position].rendered(in: context.loweredTypes))"
                        + " at position \(position)",
                    in: context.loweredTypes,
                    at: argumentPlaces[position],
                    when: ask
                )
            }

            // What is written into each slot as a literal is read as the slot
            // reads it.
            let rewritten = Call(
                selector: call.selector,
                arguments: zip(arguments, taking).map { argument, slot in slot.written(argument, in: context.loweredTypes) }
            )

            let reading = answered(
                by: signature,
                answering: context.answer(of: call.selector),
                filling: substitution.readings
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

        // A conditional answers nothing. A condition chooses a way through the
        // body, not a value; the one thing its type still says is `Never`, when
        // both arms have it. The condition runs every way and the arms are the
        // fork, judged in the environment the condition left: an arm every run
        // takes does not exist unless both are written (a conditional with no
        // other arm makes every write indefinite) and an arm that leaves hands
        // on nothing, so the write the staying arm makes is definite again: the
        // ways that finish all made it. Unreached arms are judged as well.
        case let .conditional(condition, then, otherwise):
            // A condition is data and writes nothing, so the arms stand in the
            // environment the conditional stands in.
            let head = try await inspected(
                condition,
                naming: nil,
                into: nil,
                at: place.child(.condition(of: .conditional)),
                in: environment,
                with: context,
                ask: ask
            )

            try refuseRunning(condition, asOperand: place.child(.condition(of: .conditional)), given: context, when: ask)
            try refuseCondition(head.reading, at: place.child(.condition(of: .conditional)), in: context, when: ask)

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
        // read the environment the rounds' own writes have already joined
        // into. Readings that cycle instead of converging
        // would be widened to `Any` behind the author's back. Judging says so
        // out loud, where a refusal can carry the reason; the probing ask stays
        // total and takes the widened answer.
        case let .loop(condition, body):
            let round = name

            // The fixpoint probes a round as it runs, the condition then the
            // statements. The rounds are what leave things for one another.
            // The probe reads, so a
            // probing asker takes the final probe of the statements as its
            // own walk; judging walks once more for the rewrite.
            let entry = rounded(environment, as: round, in: context.loweredTypes)
            let meets = meeting(at: place, in: context.loweredTypes, when: ask)
            let climbing = meeting(at: place, in: context.loweredTypes, when: .probing)
            let (seeded, probed, converged) = try await fixedPoint(
                from: entry,
                start: { flow in try flow.start(of: round, meeting: climbing) }
            ) { seeding -> (round: BodyWalk, flow: Flow) in
                let asked = try await inspected(
                    condition,
                    naming: nil,
                    into: nil,
                    at: place.child(.condition(of: .loop)),
                    in: seeding,
                    with: context,
                    ask: .probing
                )
                var asking = seeding

                asked.flow.apply(to: &asking)

                let walk = try await inspected(
                    body,
                    at: place.child(.round),
                    in: asking,
                    with: context,
                    ask: .probing
                )

                return (walk, asked.flow.followed(by: walk.flow))
            }

            if !converged {
                try refuse(
                    "the names this loop writes never converge"
                        + " on one reading, so the build cannot say what"
                        + " they hold",
                    at: place,
                    when: ask
                )
            }

            let head = try await inspected(
                condition,
                naming: nil,
                into: nil,
                at: place.child(.condition(of: .loop)),
                in: seeded,
                with: context,
                ask: ask
            )

            try refuseRunning(condition, asOperand: place.child(.condition(of: .loop)), given: context, when: ask)
            try refuseCondition(head.reading, at: place.child(.condition(of: .loop)), in: context, when: ask)

            // The statements run where the condition left things.
            var asked = seeded

            head.flow.apply(to: &asked)

            let rounds = ask.rewrites
                ? try await inspected(body, at: place.child(.round), in: asked, with: context, ask: ask)
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

            return Inspection(
                rewritten: ask.rewrites ? .loop(while: head.rewritten, body: rounds.body) : expression,
                calls: head.calls + rounds.calls,
                judgements: head.judgements.absorbing(rounds.judgements),
                reading: .null,
                // The round is the loop's own name, read in the condition and
                // the body alike.
                flow: ended.outside(Set([round].compactMap { $0 })),
                literalShape: nil
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
            let failures = Derivation().failing(
                block,
                given: context.failing(of:),
                bound: environment.compactMapValues(\.declaredType),
                in: context.loweredTypes
            )

            if failures.failsNothing {
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
                into: declared,
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
                into: declared,
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
    // visible, written into `declared`. A result after a statement no run
    // comes back from is judging's to refuse. The probing ask answers `Never`
    // and moves on.
    private func inspected(
        block: Block,
        into declared: LoweredType?,
        at place: Place,
        in environment: [Name: Binding],
        with context: TypingContext,
        ask: Ask
    ) async throws -> (
        block: Block,
        calls: [CallSite],
        judgements: JudgementTable,
        reading: LoweredType,
        literalShape: LiteralShape?,
        flow: Flow
    ) {
        let body = try await inspected(
            block.body,
            at: place.child(.body),
            in: environment,
            with: context,
            ask: ask
        )

        // Where the result reads, or why it does not. A block's result sits
        // after its statements. It reads in the environment the body left, and
        // a body no run comes back from leaves it nothing to run, refused.
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
                into: declared,
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
            let target = try writtenInto(by: written.binding, in: environment, with: context, at: here, when: ask)
            let statement = target.map { into in
                Statement(binding: written.binding, expression: into.completing(written.expression, in: context.loweredTypes))
            } ?? written

            let inner = try await inspected(
                statement.expression,
                naming: statement.binding?.introduced,
                into: target,
                at: here,
                in: environment,
                with: context,
                ask: ask
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
                rewritten.append(Statement(binding: statement.binding, expression: inner.rewritten))

                // What never finishes binds nothing, so a name on it
                // promises a binding that cannot happen.
                if statement.binding != nil {
                    try refuse(Expression.nameOnWhatNeverFinishes, at: here, when: ask)
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

            // A write's path, as the walk where it lands placed it.
            var placed: LoweredPath?

            switch statement.binding {
            case let .constant(id, _)?:
                locals.insert(id)
                environment[id] = Binding(
                    .fixed(declared: declaredType),
                    try held(inner.reading, writing: inner.written, declaredAs: target, at: here, with: context, when: ask)
                )
                into = target

            case let .variable(id, _)?:
                locals.insert(id)
                environment[id] = Binding(
                    declaredType.map(Binding.Holding.declared) ?? .assigned,
                    try held(inner.reading, writing: inner.written, declaredAs: target, at: here, with: context, when: ask)
                )
                into = target

            // A write to a whole variable retypes it, the way a declaration
            // did, unless the box's type is fixed elsewhere, in which case what
            // is written has to fit. A box a closure or a call took reads as
            // the type it is held to after a whole write, since the taker may
            // write any value of that type later. A write through a path is
            // judged against the type the path reaches, and leaves the
            // variable's type as it was.
            case let .assignment(path)?:
                guard let id = path.head, let box = environment[id] else { break }

                // The load holds a write's head to a variable.
                guard box.heldType != nil || box.holding == .assigned else { break }

                if box.heldType == nil, path.segments.count == 1 {
                    environment[id] = Binding(.assigned, inner.reading)
                    placed = LoweredPath([.name(id, optional: false)])

                    if !locals.contains(id) {
                        flowed.land((inner.reading, true), on: id)
                    }

                    break
                }

                guard
                    let landed = try await landing(path, from: box, in: environment, with: context, at: here, when: ask)
                else { break }

                placed = landed.placed
                into = try refuseUnfit(
                    inner.written,
                    writtenTo: path,
                    at: landed.slot,
                    of: box,
                    with: context,
                    at: here,
                    when: ask
                )

                if case let .held(held) = box.holding, path.segments.count == 1 {
                    environment[id] = Binding(.held(held), held)

                    if !locals.contains(id) {
                        flowed.land((held, true), on: id)
                    }
                } else if box.heldType == nil, !locals.contains(id), let current = environment[id]?.type {
                    flowed.land((current, true), on: id)
                }

            // A nameless statement writes no name for a later reading to
            // find.
            case nil:
                break
            }

            // Literals are read as the type they land in reads them.
            var value = inner.rewritten

            if let into, ask.rewrites {
                value = into.written(value, in: context.loweredTypes)
            }

            let standing = Statement(
                binding: placed.map { placed in .assignment(placed.path) } ?? statement.binding,
                expression: value
            )

            // Lowering reads a write's path at the place its statement stands
            // at as judging leaves it.
            if let placed, ask.rewrites {
                judgements.record(placed, writtenAt: place.statement(standing, at: position))
            }

            rewritten.append(standing)
        }

        return (ask.rewrites ? rewritten : body, calls, judgements, environment, .null, flowed, locals)
    }

    // The environment a loop's insides read: the enclosing names plus the
    // round, where the loop binds one. One maker, because the fixpoint and
    // its asker both read it.
    private func rounded(
        _ environment: [Name: Binding],
        as round: Name?,
        in table: LoweredTypeTable
    ) -> [Name: Binding] {
        guard let round else { return environment }

        return environment.merging([round: Binding(.fixed(declared: nil), table.prelude(TypeSpelling.round))]) { _, new in new }
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
            caught[failure] = Binding(.fixed(declared: nil), context.loweredTypes.prelude(TypeSpelling.failure))
        }

        return caught
    }

    // A round's body, read in the environment its own earlier rounds may have
    // written. The caller hands the one reader its rounds have, the body's flow
    // joins into the entry environment, and the body is re-read until the
    // reading stops moving. The reader reads with the probing ask, because a
    // refusal mid-climb would be a refusal of an environment no run ever stands
    // in. A body that writes nothing outward converges on the first look; a
    // chain of writes converges one link per look, so the bound is the chain's
    // own size: the names the body writes, times the few steps the join ladder
    // has. Past it the readings are not climbing (they are cycling) and
    // everything the body writes falls to `Any`, or to the type it is held to
    // where something took it, over-wide and never wrong; the judging ask
    // answers that state out loud, where it can refuse.
    private func fixedPoint<Round>(
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
        let (round, _) = try await read(widened)

        return (widened, round, false)
    }

    // Where ways that each held one box meet. A taker on either way was
    // judged against the type its way held, and goes on writing that type
    // after the meeting, so the two ways agree only where they held the box
    // to one type. Anything else is refused here.
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
    private func failsHere(
        _ expression: Expression,
        in environment: [Name: Binding],
        given context: TypingContext
    ) -> Bool {
        !Derivation().failingHere(
            expression,
            given: context.failing(of:),
            bound: { name in environment[name]?.declaredType },
            in: context.loweredTypes
        ).failsNothing
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
                case let .held(held) = box.holding,
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
        declaredAs declared: LoweredType?,
        at place: Place,
        with context: TypingContext,
        when ask: Ask
    ) throws -> LoweredType {
        guard let declared else { return given }

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

        guard case .judging = ask else { return declared }

        if let refusal = refusal(
            writing: written,
            to: declared,
            as: "holds",
            in: context.loweredTypes,
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }

        return declared
    }

    // The type a statement writes its value into, where it is known before
    // the value is read: what a name declares, or what a write reaches in a
    // box held to a type or through a path. A whole write a box takes as its
    // new type writes into none. A write's path is written before its value,
    // so a path that may not be written is refused here, with its own reason,
    // whatever the value is.
    private func writtenInto(
        by binding: Statement.Binding?,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws -> LoweredType? {
        switch binding {
        case let .constant(_, declared?)?, let .variable(_, declared?)?:
            return declared.lowered(in: context.loweredTypes)

        case let .assignment(path)?:
            guard let head = path.head, let box = environment[head] else { return nil }

            guard path.segments.count > 1 else { return box.heldType }

            switch writable(path, from: box, in: environment, with: context, at: place) {
            case let .refused(reason):
                try refuse(reason, at: place, when: ask)
                return nil

            case let .reads(reached, _):
                return reached
            }

        default:
            return nil
        }
    }

    // Where a write lands, and the path placed for it there: the box's own
    // type for a whole write to a box held to one, else what the path
    // reaches. The value runs before the write lands, and may itself write
    // the head or a name the path indexes with, so the path is walked in the
    // names as the value left them. Under a folding scope its constant
    // indexes settle, so no constant name survives into the image, and what
    // an index settled to stands as if it were written there and is judged
    // as such. Nil where the probing ask meets a refusal.
    private func landing(
        _ path: Path,
        from box: Binding,
        in environment: [Name: Binding],
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) async throws -> (slot: LoweredType, placed: LoweredPath)? {
        if let head = path.head, path.segments.count == 1, let fixed = box.heldType {
            return (fixed, LoweredPath([.name(head, optional: false)]))
        }

        switch writable(path, from: box, in: environment, with: context, at: place) {
        case let .refused(reason):
            try refuse(reason, at: place, when: ask)
            return nil

        case let .reads(reached, placed):
            guard case let .judging(folding?, _) = ask else { return (reached, placed) }

            let folded = try await foldedIndexReferences(placed, at: place, folding: folding)

            if
                folded != placed,
                case let .refused(reason) = writable(folded.path, from: box, in: environment, with: context, at: place)
            {
                throw BuildError(reason, at: place)
            }

            return (reached, folded)
        }
    }

    // A write held to where it lands: refused where what is written does
    // not fit what the path reaches, a type parameter there taking only a
    // value of it. Answers the type the write was held to, or nil where it
    // was refused.
    private func refuseUnfit(
        _ written: LiteralShape,
        writtenTo path: Path,
        at slot: LoweredType,
        of box: Binding,
        with context: TypingContext,
        at place: Place,
        when ask: Ask
    ) throws -> LoweredType? {
        guard fits(written, into: slot, of: box, in: context.loweredTypes) else {
            try refuse(
                "writes '\(path.rendered)' as \(written.rendered(in: context.loweredTypes)), and it holds"
                    + " \(slot.rendered(in: context.loweredTypes))",
                at: place,
                when: ask
            )
            return nil
        }

        guard case .judging = ask else { return slot }

        if let refusal = refusal(
            writing: written,
            to: slot,
            as: "writes '\(path.rendered)' as",
            in: context.loweredTypes,
            at: place
        ) {
            throw BuildError(refusal, at: place)
        }

        try refuseUnfilled(
            written,
            at: slot,
            as: "writes '\(path.rendered)' as \(written.rendered(in: context.loweredTypes))",
            in: context.loweredTypes,
            at: place,
            when: ask
        )

        return slot
    }

    // A type parameter the body does not fill is one type it knows nothing
    // about, so a write into a place reading it, and an argument at a slot
    // reading it, takes only a value of it there. A literal is held part by
    // part, and only a part standing where the slot reads the parameter is
    // held to it. A slot handed in place takes exactly its own type, which
    // the call's check holds.
    private func refuseUnfilled(
        _ written: LiteralShape,
        at slot: LoweredType,
        as subject: String,
        in loweredTypes: LoweredTypeTable,
        at place: Place,
        when ask: Ask
    ) throws {
        guard slot.namesParameter, !slot.isInout else { return }

        let holds = written.everyPart(along: slot, inPlace: false, in: loweredTypes) { slot, part, _ in
            !slot.namesParameter || slot.accepts(part.folded, in: loweredTypes)
        }

        guard !holds else { return }

        try refuse(
            "\(subject), where its slot reads \(slot.rendered(in: loweredTypes)):"
                + " a type parameter the body does not fill takes only a value of it",
            at: place,
            when: ask
        )
    }

    private func check(
        _ site: CallSite,
        against declared: Signature,
        with context: TypingContext
    ) throws {
        let call = site.call
        let loweredTypes = context.loweredTypes
        let subject = "sending '\(call.selector)'"

        // A declaration with a type parameter in it is checked with the
        // parameter filled, or a slot standing for whatever arrives would
        // refuse whatever arrived. `instantiated` judges the filling (a
        // parameter read two ways has no answer, a bounded one takes only what
        // answers its bounds), so this only gathers what the call wrote into
        // each slot.
        let declaredSlots = context.slots(of: call.selector)
        let slots: [Slot]

        switch instantiated(
            declared,
            over: declaredSlots,
            substitution: filling(declared, over: declaredSlots, against: site.readings, with: context),
            shaped: site.shapes,
            in: loweredTypes,
            at: site.place
        ) {
        case let .refusal(reason):
            throw BuildError(
                "sending '\(call.selector)': \(reason)",
                at: site.place
            )

        case let .fits(filled):
            slots = filled
        }

        try check(
            reading: site.readings,
            shaped: site.shapes,
            against: slots.map(\.type),
            naming: slots,
            as: subject,
            in: loweredTypes,
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
    // composition it mentions held to its bounds. What an argument
    // holds is read from the body it was written in, so a name bound to a call
    // carries that call's declared answer. A declaration's slots name each
    // position; a value's type writes the positions alone.
    private func check(
        reading readings: [LoweredType],
        shaped shapes: [Int: LiteralShape],
        against types: [LoweredType],
        naming slots: [Slot]?,
        as subject: String,
        in loweredTypes: LoweredTypeTable,
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

            // A pair the link decides is written down at the call, which an
            // object records; a refusal here stands at the argument.
            if let refusal = refusal(
                writing: given,
                to: type,
                as: "\(quoted) holds",
                in: loweredTypes,
                at: place
            ) {
                throw BuildError("\(subject): \(refusal)", at: at)
            }
        }
    }
}
