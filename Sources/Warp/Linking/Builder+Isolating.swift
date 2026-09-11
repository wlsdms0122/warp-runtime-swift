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
        let bodies = symbols.reduce(into: [Name: (block: Block, declaring: Set<Name>)]()) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (block, Set(symbol.procedure.signature.parameters.keys))
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
                    && !isIsolated(body.block, declaring: body.declaring, given: isolated, taking: asked)
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
        taking asked: @escaping (Name) -> Signature?
    ) -> Bool {
        Isolating(isolated: isolated, asked: asked).holds(block, declared: parameters)
    }

    // MARK: - Private
    private struct Isolating {
        let isolated: Set<Name>

        // What a callee takes, which is where a call handing something in
        // place says which slot it lands in. Asked rather than held, because
        // where a declaration's signature is read from is the caller's: the
        // link's rows once they stand, and the documents themselves before.
        let asked: (Name) -> Signature?

        func holds(_ block: Block, declared: Set<Name>) -> Bool {
            var declared = declared

            return holds(block.body, declared: &declared)
                && (block.result.map { result in holds(result, declared: declared) } ?? true)
        }

        // A body in order. Each statement is judged against what was declared
        // before it, and a variable it introduces is declared for the rest.
        private func holds(_ body: [Statement], declared: inout Set<Name>) -> Bool {
            for statement in body {
                switch statement.binding {
                case let .assignment(path)?:
                    guard let head = path.head, declared.contains(head) else { return false }

                case .constant?, .variable?, nil:
                    break
                }

                guard holds(statement.expression, declared: declared) else { return false }

                if case let .variable(name, _)? = statement.binding {
                    declared.insert(name)
                }
            }

            return true
        }

        private func holds(_ body: [Statement], declared: Set<Name>) -> Bool {
            var inner = declared

            return holds(body, declared: &inner)
        }

        private func holds(_ expression: Expression, declared: Set<Name>) -> Bool {
            switch expression {
            case .literal, .reference:
                return true

            case .apply:
                return false

            case let .cast(value, _, _):
                return holds(value, declared: declared)

            case let .array(array):
                return array.allSatisfy { element in holds(element, declared: declared) }

            case let .record(record):
                return record.values.allSatisfy { field in holds(field, declared: declared) }

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

                return (call.receiver.map { receiver in holds(receiver, declared: declared) } ?? true)
                    && call.arguments.values.allSatisfy { argument in holds(argument, declared: declared) }

            case let .block(block):
                return holds(block, declared: declared)

            case let .conditional(condition, then, otherwise):
                return holds(condition, declared: declared)
                    && holds(then, declared: declared)
                    && (otherwise.map { arm in holds(arm, declared: declared) } ?? true)

            case let .loop(condition, body, _):
                return holds(condition, declared: declared) && holds(body, declared: declared)

            case let .attempt(body, rescue, _):
                return holds(body, declared: declared) && holds(rescue, declared: declared)

            case let .leave(leave):
                return leave.value.map { value in holds(value, declared: declared) } ?? true
            }
        }
    }
}
