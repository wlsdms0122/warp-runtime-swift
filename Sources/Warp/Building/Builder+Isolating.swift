//
//  Builder+Isolating.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Which declarations touch no name another body could touch at the same time.
// Worked out the way purity is: a native says so about itself, a body starts
// isolated, and one is struck when its body writes a name it did not declare,
// hands one in place, calls a value, or calls a declaration that was struck,
// until nothing more is struck.
extension Builder {
    // MARK: - Internal
    func isolated(
        among symbols: [Symbol],
        settling isolated: inout Set<Name>,
        taking asked: @escaping (Name) -> Signature?
    ) {
        let bodies = symbols.reduce(
            into: [Name: (block: Block, declaring: Set<Name>, applying: Set<Name>)]()
        ) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (
                block,
                Set(symbol.procedure.signature.parameters.keys),
                symbol.procedure.signature.isolatedProcedures
            )
        }

        isolated.formUnion(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyIsolated != false }
                .map(\.declared)
        )

        // Only what this call was handed can be struck, for the reason purity
        // reads the same way: what was settled before it stands in front of
        // it and reaches nothing here.
        while true {
            let struck = bodies.compactMap { name, body in
                isolated.contains(name)
                    && !isIsolated(
                        body.block,
                        declaring: body.declaring,
                        given: isolated,
                        applying: body.applying,
                        taking: asked
                    )
                    ? name
                    : nil
            }

            guard !struck.isEmpty else { return }

            isolated.subtract(struck)
        }
    }

    // Whether a body writes only names it declares and calls only isolated
    // declarations. The names it declares are read in scope order: a
    // variable is written only after the statement that introduced it, in
    // that body or one it encloses, so a name introduced inside a nested body
    // or a nested closure is nobody else's. A name written that was not
    // declared here is a name the body reached from outside: a module
    // variable, or one a closure captured.
    func isIsolated(
        _ block: Block,
        declaring parameters: Set<Name>,
        given isolated: Set<Name>,
        applying procedures: Set<Name>,
        taking asked: @escaping (Name) -> Signature?
    ) -> Bool {
        Isolating(isolated: isolated, asked: asked).holds(
            block,
            declared: parameters,
            applying: procedures
        )
    }

    // MARK: - Private
    private struct Isolating {
        let isolated: Set<Name>

        // What a callee takes, which is where a call handing something in
        // place says which slot it lands in. Asked rather than held, because
        // where a declaration's signature is read from is the caller's: the
        // link's rows once they stand, and the documents themselves before.
        let asked: (Name) -> Signature?

        func holds(_ block: Block, declared: Set<Name>, applying procedures: Set<Name>) -> Bool {
            var declared = declared
            var procedures = procedures

            return holds(block.body, declared: &declared, applying: &procedures)
                && (
                    block.result.map { result in
                        holds(result, declared: declared, applying: procedures)
                    } ?? true
                )
        }

        // A body in order. Each statement is judged against what was declared
        // before it, and a variable it introduces is declared for the rest.
        private func holds(
            _ body: [Statement],
            declared: inout Set<Name>,
            applying procedures: inout Set<Name>
        ) -> Bool {
            for statement in body {
                switch statement.binding {
                case let .assignment(path)?:
                    guard let head = path.head, declared.contains(head) else { return false }

                case .constant?, .variable?, nil:
                    break
                }

                guard holds(statement.expression, declared: declared, applying: procedures) else {
                    return false
                }

                if case let .variable(name, _)? = statement.binding {
                    declared.insert(name)
                }

                guard let introduced = statement.binding?.introduced else { continue }

                // Read forward, the way purity reads it: what a name said is
                // what stands until something else takes the spelling.
                if
                    statement.binding?.declared?.isIsolatedProcedure == true
                        || applies(statement.expression, given: procedures)
                {
                    procedures.insert(introduced)
                } else {
                    procedures.remove(introduced)
                }
            }

            return true
        }

        // Whether what this reads came out of a slot that said its procedures
        // touch no name another body could touch at the same time. The head is
        // the name the slot gave, and indexing past it keeps the claim.
        private func applies(_ expression: Expression, given procedures: Set<Name>) -> Bool {
            guard case let .reference(path) = expression, let head = path.head else { return false }

            return procedures.contains(head)
                && path.dropFirst().allSatisfy { segment in segment.named == nil }
        }

        private func holds(
            _ body: [Statement],
            declared: Set<Name>,
            applying procedures: Set<Name>
        ) -> Bool {
            var inner = declared
            var applying = procedures

            return holds(body, declared: &inner, applying: &applying)
        }

        private func holds(
            _ expression: Expression,
            declared: Set<Name>,
            applying procedures: Set<Name>
        ) -> Bool {
            switch expression {
            case .literal, .reference:
                return true

            // Applying a name a slot said holds an isolated procedure runs a
            // body that writes only its own names, which is the whole of what
            // is asked here. Any other value is the run's answer and says
            // nothing.
            case let .apply(callee, arguments):
                return applies(callee, given: procedures)
                    && arguments.values.allSatisfy { argument in
                        holds(argument, declared: declared, applying: procedures)
                    }

            case let .cast(value, _, _):
                return holds(value, declared: declared, applying: procedures)

            case let .array(array):
                return array.allSatisfy { element in holds(element, declared: declared, applying: procedures) }

            case let .record(record):
                return record.values.allSatisfy { field in holds(field, declared: declared, applying: procedures) }

            // A closure written here is judged for its own isolation when it is
            // made; making it touches nothing.
            case .closure:
                return true

            case let .call(call):
                guard
                    isolated.contains(call.selector),
                    let signature = asked(call.selector)
                else {
                    return false
                }

                for (name, parameter) in signature.parameters where parameter.declared.isInout {
                    guard
                        case let .reference(path)? = call.handed(name, to: signature),
                        let head = path.head
                    else { continue }

                    guard declared.contains(head) else { return false }
                }

                return (call.receiver.map { receiver in holds(receiver, declared: declared, applying: procedures) } ?? true)
                    && call.arguments.values.allSatisfy { argument in holds(argument, declared: declared, applying: procedures) }

            case let .block(block):
                return holds(block, declared: declared, applying: procedures)

            case let .conditional(condition, then, otherwise):
                return holds(condition, declared: declared, applying: procedures)
                    && holds(then, declared: declared, applying: procedures)
                    && (otherwise.map { arm in holds(arm, declared: declared, applying: procedures) } ?? true)

            case let .loop(condition, body, _):
                return holds(condition, declared: declared, applying: procedures) && holds(body, declared: declared, applying: procedures)

            case let .attempt(body, rescue, _):
                return holds(body, declared: declared, applying: procedures) && holds(rescue, declared: declared, applying: procedures)

            case let .leave(leave):
                return leave.value.map { value in holds(value, declared: declared, applying: procedures) } ?? true
            }
        }
    }
}
