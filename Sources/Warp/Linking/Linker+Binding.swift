//
//  Linker+Binding.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Resolving is a rewrite. A selector a document writes is not yet what it
// means — it means whichever declaration the writing module can see — and it
// is settled here, so the image the executor runs holds no name whose meaning
// depends on where it was written. A reference to a constant is settled too,
// but later: the typing walk judges its dots first, and folds it where the
// judgment lands.
//
// The walk is total over `Expression` on purpose. A case added to the language
// and forgotten here would be a case whose names silently stay unresolved, and
// silence is exactly the failure a linker exists to prevent.
extension Linker {
    // MARK: - Internal
    // A native procedure has no names to resolve — its body is Swift, which the
    // linker cannot read and does not need to.
    func bind(
        _ procedure: Procedure,
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> Procedure {
        guard let block = procedure.block else { return procedure }

        return Procedure(
            description: procedure.description,
            signature: procedure.signature,
            implementation: .body(
                try bind(
                    block,
                    within: origin,
                    symbols: symbols,
                    at: place.key("body")
                )
            )
        )
    }

    func bind(
        _ block: Block,
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> Block {
        Block(
            body: try bind(
                block.body,
                within: origin,
                symbols: symbols,
                at: place
            ),
            result: try block.result.map { result in
                try bind(
                    result,
                    within: origin,
                    symbols: symbols,
                    at: place
                )
            }
        )
    }

    // A body with no result slot — the walk's, and any future one whose
    // answer is nothing by grammar.
    func bind(
        _ body: [Statement],
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> [Statement] {
        try body.enumerated().map { position, statement in
            try bind(
                statement,
                at: position,
                within: origin,
                symbols: symbols,
                at: place
            )
        }
    }

    // MARK: - Private
    private func bind(
        _ statement: Statement,
        at position: Int,
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> Statement {
        Statement(
            id: statement.id,
            binding: statement.binding,
            expression: try bind(
                statement.expression,
                within: origin,
                symbols: symbols,
                at: place.statement(statement.id, at: position)
            )
        )
    }

    // Internal for the one lone-expression caller: a constant's expression,
    // whose selectors mean what its module sees exactly as a body's do.
    func bind(
        _ expression: Expression,
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> Expression {
        func inner(_ expression: Expression) throws -> Expression {
            try bind(
                expression,
                within: origin,
                symbols: symbols,
                at: place
            )
        }

        func inner(_ block: Block) throws -> Block {
            try bind(
                block,
                within: origin,
                symbols: symbols,
                at: place
            )
        }

        func inner(_ body: [Statement]) throws -> [Statement] {
            try bind(
                body,
                within: origin,
                symbols: symbols,
                at: place
            )
        }

        switch expression {
        case .literal, .reference:
            return expression

        case let .leave(leave):
            guard let value = leave.value else { return expression }

            return .leave(Leave(reach: leave.reach, target: leave.target, value: try inner(value)))

        // The shape a cast names is the qualifying pass's to resolve, not
        // the binding pass's — nothing in a type spelling is a symbol.
        case let .cast(value, type, optional):
            return .cast(try inner(value), as: type, optional: optional)

        case let .array(array):
            return .array(try array.map(inner))

        case let .record(record):
            return .record(try record.mapValues(inner))

        case let .closure(procedure):
            guard let block = procedure.block else { return expression }

            return .closure(
                Procedure(
                    description: procedure.description,
                    signature: procedure.signature,
                    implementation: .body(try inner(block))
                )
            )

        case let .invoke(callee, arguments):
            return .invoke(try inner(callee), arguments: try arguments.mapValues(inner))

        case let .block(block):
            return .block(try inner(block))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try inner(condition),
                then: try inner(then),
                else: try otherwise.map(inner)
            )

        case let .loop(condition, body, round):
            return .loop(
                while: try inner(condition),
                body: try inner(body),
                round: round
            )

        case let .iteration(material, body, element):
            return .iteration(
                over: try inner(material),
                body: try inner(body),
                element: element
            )

        case let .attempt(block, rescue, failure):
            return .attempt(try inner(block), rescue: try inner(rescue), failure: failure)

        case let .dispatch(dispatch):
            return .dispatch(
                try bind(
                    dispatch,
                    within: origin,
                    symbols: symbols,
                    at: place
                )
            )
        }
    }

    // The selector is the one thing here whose meaning is a fact about where it
    // was written. An installed word answers first and is not a symbol; anything
    // else is resolved against the writing module, and an ambiguity is refused
    // rather than decided by link order.
    private func bind(
        _ dispatch: Dispatch,
        within origin: Int,
        symbols: SymbolSpace,
        at place: Place
    ) throws -> Dispatch {
        func inner(_ expression: Expression) throws -> Expression {
            try bind(
                expression,
                within: origin,
                symbols: symbols,
                at: place
            )
        }

        let selector: String

        // The rule's own account of the failure, not a recomputation — the
        // candidates an ambiguity names are the ones the rule weighed.
        switch symbols.resolution(of: dispatch.selector, from: origin) {
        case let .resolved(qualified):
            selector = qualified

        case let .ambiguous(candidates):
            throw LinkError(
                "sends '\(dispatch.selector)', which"
                    + " \(candidates.joined(separator: " and ")) both declare"
                    + " — name the one you meant",
                at: place
            )

        case .unresolved:
            throw LinkError(
                "sends '\(dispatch.selector)', which no module in this"
                    + " link declares",
                at: place
            )
        }

        return Dispatch(
            receiver: try dispatch.receiver.map(inner),
            selector: selector,
            arguments: try dispatch.arguments.mapValues(inner)
        )
    }
}
