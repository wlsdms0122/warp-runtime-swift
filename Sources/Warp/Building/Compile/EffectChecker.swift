//
//  EffectChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a body reaches, read against what its declaration says: whether it
// answers without running, whether it touches no name another body could
// touch at once, and what may come out of it when the work goes wrong. Every
// callee is read by its own declaration, so one body is read alone.
struct EffectChecker {
    // What a body is walked for. Constness and isolation are read by one walk
    // and differ only in these: what a callee's declaration says to hold the
    // fact, what a slot's type says, which names a body loses it by reading,
    // and the word a refusal says.
    private struct Fact {
        // MARK: - Property
        let held: (Signature) -> Bool
        let claim: (LoweredType) -> Bool
        let unread: Set<Name>
        let word: String

        // MARK: - Initializer
        // Answering without running, lost by reading a name in `unread`.
        static func const(unread: Set<Name>) -> Fact {
            Fact(
                held: { callee in callee.constness == .const },
                claim: \.isConstProcedure,
                unread: unread,
                word: "const"
            )
        }

        // MARK: - Public
        // The same fact where a body introduced `name`: under it the spelling
        // reads the new name.
        func introducing(_ name: Name?) -> Fact {
            guard let name else { return self }

            return Fact(held: held, claim: claim, unread: unread.subtracting([name]), word: word)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The declarations a body may call and the table its types are read in.
    private let context: TypingContext

    // MARK: - Initializer
    init(_ context: TypingContext) {
        self.context = context
    }

    // MARK: - Public
    // What a body does beyond what its declaration says, or nil where it
    // keeps to it: a body declared const reaches outside the run, one
    // declared isolated touches what another body could touch at once, or
    // one may fail with more than its declaration names. `environment` is
    // what each name in scope is bound as, before the first statement.
    func refusal(of body: Body, declared signature: Signature, in environment: [Name: Binding]) -> String? {
        let declared = environment.compactMapValues(\.declaredType)

        // A body reading a module variable answers by the run's state, and so
        // does one writing a name outside the parameters it owns, or handing
        // such a name in place to a call.
        let const = Fact.const(
            unread: Set(environment.filter { _, bound in bound.declarer == .module && bound.isBox }.keys)
        )

        // A name written that the body does not declare is one it reached from
        // outside: a module variable, or one a closure captured.
        let isolated = Fact(
            held: { callee in callee.isolation == .isolated },
            claim: \.isIsolatedProcedure,
            unread: [],
            word: "isolated"
        )

        if
            signature.constness == .const,
            let reached = breaking(body, const, declaring: signature.ownedParameters, bound: declared)
        {
            return "is declared const, and \(reached)"
        }

        if
            signature.isolation == .isolated,
            let touched = breaking(body, isolated, declaring: Set(signature.names), bound: declared)
        {
            return "is declared isolated, and \(touched)"
        }

        let failing = self.failing(body, bound: declared)

        guard failing.fails(within: signature.failing) else {
            return "may fail with \(failing.rendered), and its declaration says \(signature.failing.rendered)"
        }

        return nil
    }

    // What reading an operand runs, or nil where it answers without running.
    // An operand is read rather than run: a call's and a value call's
    // operands, a condition, a constant and a variable's start. It is held
    // as a body declared const is, except that every name in scope is one it
    // may read: what reading a module variable costs a body is the promise
    // of answering the same thing twice, and an operand makes none. A
    // construct in one is the load's to refuse.
    func running(_ operand: Expression, in environment: [Name: Binding]) -> String? {
        breaking(
            operand,
            .const(unread: []),
            declaring: Set(environment.keys),
            bound: environment.compactMapValues(\.declaredType)
        )
    }

    // What may come out of this node itself, apart from the nodes it holds:
    // the one judgement of where a run may fail, which `failing` gathers over
    // a tree and the type check asks where a way may end by failing.
    func failingHere(_ expression: Expression, bound declared: (Name) -> LoweredType?) -> Failing {
        switch expression {
        // A cast that names a type the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(_, _, optional):
            return optional ? .these([]) : .these([CastRefused.type])

        // Which value is called is decided at run time, so what may come out
        // of it is what the type written where it came from says, and
        // anything where nothing was written.
        case let .apply(callee, _):
            return reached(callee, given: declared)?.procedureFailing ?? .anything

        case let .call(call):
            return context.signature(of: call.selector)?.failing ?? .anything

        case .literal, .reference, .closure, .array, .struct, .dictionary, .conditional, .loop, .attempt, .leave:
            return .these([])
        }
    }

    // The type written for the value the name a statement binds holds,
    // which is what a call of that value leans on. A name that wrote its type
    // holds that. A fixed name that wrote none holds the one written where
    // its value came from, by the rule `reached` reads. A variable that wrote
    // none holds whatever its writes leave, which nothing wrote, so it holds
    // none.
    func declaredType(
        of binding: Statement.Binding,
        reading expression: Expression,
        given declared: (Name) -> LoweredType?
    ) -> LoweredType? {
        switch binding {
        case let .constant(_, written):
            return written?.lowered(in: context.loweredTypes) ?? reached(expression, given: declared)

        case let .variable(_, written):
            return written?.lowered(in: context.loweredTypes)

        case .assignment:
            return nil
        }
    }

    // MARK: - Private
    // What may come out of a body: everything its statements may fail with.
    // `bound` is the type written for what each name in scope holds, which a
    // call of a value is judged on; a name a statement binds holds it for the
    // rest of the body, by the rule `declaredType` reads.
    private func failing(_ body: Body, bound declaredTypes: [Name: LoweredType]) -> Failing {
        var declaredTypes = declaredTypes
        var carried = Failing.these([])

        for statement in body.statements {
            carried = carried.joined(self.failing(statement.expression, bound: declaredTypes))
            declaring(statement, into: &declaredTypes)
        }

        return carried
    }

    private func failing(_ expression: Expression, bound declared: [Name: LoweredType]) -> Failing {
        func read(_ inner: Expression) -> Failing {
            self.failing(inner, bound: declared)
        }

        func read(_ body: Body) -> Failing {
            self.failing(body, bound: declared)
        }

        let here = failingHere(expression, bound: { name in declared[name] })

        switch expression {
        case .literal, .reference, .closure:
            return here

        case let .cast(value, _, _):
            return read(value).joined(here)

        case let .array(array):
            return array.reduce(here) { carried, element in carried.joined(read(element)) }

        case let .struct(literal):
            return literal.values.reduce(here) { carried, field in carried.joined(read(field)) }

        case let .dictionary(entries):
            return entries.reduce(here) { carried, entry in carried.joined(read(entry.key)).joined(read(entry.value)) }

        case let .call(call):
            return call.arguments.reduce(here) { carried, argument in carried.joined(read(argument)) }

        case let .apply(callee, arguments):
            return arguments.reduce(read(callee).joined(here)) { carried, argument in carried.joined(read(argument)) }

        case let .conditional(condition, then, otherwise):
            return read(condition)
                .joined(read(then))
                .joined(otherwise.map { arm in read(arm) } ?? .these([]))

        case let .loop(condition, body):
            return read(condition).joined(read(body))

        // The rescue is what the body's failures become: they are caught here,
        // and what is left is whatever the rescue itself may fail with.
        case let .attempt(_, rescue):
            return read(rescue)

        case let .leave(leave):
            return leave.value.map(read) ?? .these([])
        }
    }

    // A body in order. Each statement is judged against what was declared
    // before it, and a variable it introduces is declared for the rest. The
    // names a body binds are its own and leave with it, so introducing one
    // reaches nothing.
    private func breaking(
        _ body: Body,
        _ fact: Fact,
        declaring names: Set<Name>,
        bound declaredTypes: [Name: LoweredType]
    ) -> String? {
        var fact = fact
        var declared = names
        var declaredTypes = declaredTypes

        for statement in body.statements {
            if case let .assignment(path)? = statement.binding {
                if let head = path.head, !declared.contains(head) {
                    return "it writes '\(head)', which it does not declare"
                }

                // What the place written is found by is read.
                if let broken = breaking(.reference(path), fact, declaring: declared, bound: declaredTypes) {
                    return broken
                }
            }

            let naming = fact.introducing(statement.nameInside)
            let broken: String? = if case let .attempt(body, rescue) = statement.expression {
                breaking(body, fact, declaring: declared, bound: declaredTypes)
                    ?? breaking(rescue, naming, declaring: declared, bound: declaredTypes)
            } else {
                breaking(statement.expression, naming, declaring: declared, bound: declaredTypes)
            }

            if let broken {
                return broken
            }

            if case let .variable(name, _)? = statement.bindingAfter {
                declared.insert(name)
            }

            fact = fact.introducing(statement.bindingAfter?.introduced)
            declaring(statement, into: &declaredTypes)
        }

        return nil
    }

    private func breaking(
        _ expression: Expression,
        _ fact: Fact,
        declaring names: Set<Name>,
        bound declared: [Name: LoweredType]
    ) -> String? {
        func breaking(_ inner: Expression) -> String? {
            self.breaking(inner, fact, declaring: names, bound: declared)
        }

        func breaking(_ body: Body) -> String? {
            self.breaking(body, fact, declaring: names, bound: declared)
        }

        func first(_ parts: [Expression]) -> String? {
            for part in parts {
                if let broken = breaking(part) { return broken }
            }

            return nil
        }

        switch expression {
        case .literal, .closure:
            return nil

        case let .reference(path):
            return path.expandingIndexReferences.lazy
                .compactMap { inner in inner.head.flatMap { head in fact.unread.contains(head) ? head : nil } }
                .first
                .map { head in "it reads the module variable '\(head)'" }

        // Where a leave goes is inside the body, so what it reaches is what it
        // carries.
        case let .leave(leave):
            return leave.value.flatMap(breaking)

        case let .cast(value, _, _):
            return breaking(value)

        case let .array(array):
            return first(array)

        case let .struct(literal):
            return first(literal.keys.sorted().compactMap { field in literal[field] })

        case let .dictionary(entries):
            return first(entries.flatMap { entry in [entry.key, entry.value] })

        case let .call(call):
            guard let signature = context.signature(of: call.selector), fact.held(signature) else {
                return "it calls '\(call.selector)', which is not declared \(fact.word)"
            }

            if let handed = unowned(call.arguments, at: signature.procedureType.inPlacePositions, declaring: names) {
                return "it hands '\(handed)', which it does not declare, in place to '\(call.selector)'"
            }

            return first(call.arguments)

        // Which value is called is the run's answer, so what it reaches is
        // said by the type written where the value came from and nowhere
        // else, and so are the positions it takes in place.
        case let .apply(callee, arguments):
            if let broken = breaking(callee) { return broken }

            guard let reached = reached(callee, given: { name in declared[name] }), fact.claim(reached) else {
                return "it calls a value nothing written says is \(fact.word)"
            }

            if let handed = unowned(arguments, at: reached.inPlacePositions, declaring: names) {
                return "it hands '\(handed)', which it does not declare, in place to a value it calls"
            }

            return first(arguments)

        // Which part of a construct runs is decided inside the body, so a
        // construct holds the fact as far as the parts it holds.
        case let .conditional(condition, then, otherwise):
            return breaking(condition) ?? breaking(then) ?? otherwise.flatMap(breaking)

        case let .loop(condition, body):
            return breaking(condition) ?? breaking(body)

        case let .attempt(body, rescue):
            return breaking(body) ?? breaking(rescue)
        }
    }

    // The type a name a statement binds holds for the rest of its body. A
    // later name of the same spelling is a different name, so the table is
    // read forward.
    private func declaring(_ statement: Statement, into declaredTypes: inout [Name: LoweredType]) {
        guard let binding = statement.bindingAfter, let name = binding.introduced else { return }

        let reading = declaredTypes

        declaredTypes[name] = declaredType(
            of: binding,
            reading: statement.expression,
            given: { name in reading[name] }
        )
    }

    // The type written where the value this reads came from, and nil where
    // nothing was written. A closure literal writes its signature, a cast the
    // type it names, a call the answer its callee declares and a call of a
    // value the answer the value's written type says, and the value is held
    // to that type where it is made, cast or answered. A name follows
    // the type its slot declared past its head: brackets read an element of
    // a list or an entry of a map, and a dot reads a field a struct type
    // declares. A list or a map of them says it about every element or entry,
    // and the value was judged against that type when it was handed over, so
    // what the type says of the part is what the slot said.
    private func reached(_ expression: Expression, given declared: (Name) -> LoweredType?) -> LoweredType? {
        switch expression {
        case let .closure(procedure):
            return procedure.signature.type.lowered(in: context.loweredTypes)

        case let .cast(_, type, optional):
            let named = type.lowered(in: context.loweredTypes)

            return optional ? .nullable(named) : named

        case let .call(call):
            return context.signature(of: call.selector).map { signature in
                signature.returns.lowered(
                    in: context.loweredTypes,
                    bounds: signature.bounds,
                    sameTypes: signature.sameTypes
                )
            }

        case let .apply(callee, _):
            return reached(callee, given: declared)?.procedureReturns

        default:
            break
        }

        guard case let .reference(path) = expression, let head = path.head else { return nil }

        return path.segments.dropFirst().reduce(declared(head)) { reached, segment in
            switch segment {
            case .index, .indexRef:
                return reached?.element

            case let .name(name, _):
                return reached?.dotted(name, in: context.loweredTypes)
            }
        }
    }

    // The first name a call hands in place at these positions that the body
    // does not own. A name handed in place is written by the callee, so the
    // call writes it here, and one the body does not own reaches the run's
    // state.
    private func unowned(_ arguments: [Expression], at positions: Set<Int>, declaring names: Set<Name>) -> Name? {
        positions.sorted().lazy.compactMap { position -> Name? in
            guard
                arguments.indices.contains(position),
                case let .reference(path) = arguments[position],
                let head = path.head,
                !names.contains(head)
            else { return nil }

            return head
        }
        .first
    }
}
