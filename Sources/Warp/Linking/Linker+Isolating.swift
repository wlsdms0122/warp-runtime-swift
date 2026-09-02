//
//  Linker+Isolating.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Which bodies touch no name another body could touch at the same time. Worked
// out the way purity is: every declaration starts isolated, and one is struck
// when its body writes a name it did not declare, hands one in place, calls a
// value, or calls a declaration that was struck — until nothing more is struck.
extension Linker {
    // MARK: - Internal
    func isolated(
        among symbols: [Symbol],
        pure: Set<String>,
        signatures: [String: Signature]
    ) -> Set<String> {
        let bodies = symbols.reduce(into: [String: (block: Block, declaring: Set<String>)]()) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (block, Set(symbol.procedure.signature.parameters.keys))
        }

        var isolated = Set(symbols.map(\.declared))

        while true {
            let struck = isolated.filter { name in
                guard let body = bodies[name] else { return false }

                return !pure.contains(name)
                    && !isIsolated(body.block, declaring: body.declaring, given: isolated, signatures: signatures)
            }

            guard !struck.isEmpty else { return isolated }

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
        declaring parameters: Set<String>,
        given isolated: Set<String>,
        signatures: [String: Signature]
    ) -> Bool {
        Isolating(isolated: isolated, signatures: signatures).holds(block, declared: parameters)
    }

    // MARK: - Private
    private struct Isolating {
        let isolated: Set<String>
        let signatures: [String: Signature]

        func holds(_ block: Block, declared: Set<String>) -> Bool {
            var declared = declared

            return holds(block.body, declared: &declared)
                && (block.result.map { result in holds(result, declared: declared) } ?? true)
        }

        // A body in order. Each statement is judged against what was declared
        // before it, and a variable it introduces is declared for the rest.
        private func holds(_ body: [Statement], declared: inout Set<String>) -> Bool {
            for statement in body {
                switch statement.binding {
                case let .assignment(path)?:
                    guard let head = path.head, declared.contains(head) else { return false }

                case .constant?, .variable?, nil:
                    break
                }

                guard holds(statement.expression, declared: declared) else { return false }

                if case let .variable(name)? = statement.binding {
                    declared.insert(name)
                }
            }

            return true
        }

        private func holds(_ body: [Statement], declared: Set<String>) -> Bool {
            var inner = declared

            return holds(body, declared: &inner)
        }

        private func holds(_ expression: Expression, declared: Set<String>) -> Bool {
            switch expression {
            case .literal, .reference:
                return true

            case .invoke:
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

            case let .dispatch(dispatch):
                guard isolated.contains(dispatch.selector), let signature = signatures[dispatch.selector] else {
                    return false
                }

                for (name, parameter) in signature.parameters where parameter.declared.isInout {
                    guard
                        case let .reference(path)? = dispatch.handed(name, to: signature),
                        let head = path.head
                    else { continue }

                    guard declared.contains(head) else { return false }
                }

                return (dispatch.receiver.map { receiver in holds(receiver, declared: declared) } ?? true)
                    && dispatch.arguments.values.allSatisfy { argument in holds(argument, declared: declared) }

            case let .block(block):
                return holds(block, declared: declared)

            case let .conditional(condition, then, otherwise):
                return holds(condition, declared: declared)
                    && holds(then, declared: declared)
                    && (otherwise.map { arm in holds(arm, declared: declared) } ?? true)

            case let .loop(condition, body, _):
                return holds(condition, declared: declared) && holds(body, declared: declared)

            case let .iteration(collection, body, _):
                return holds(collection, declared: declared) && holds(body, declared: declared)

            case let .attempt(body, rescue, _):
                return holds(body, declared: declared) && holds(rescue, declared: declared)

            case let .leave(leave):
                return leave.value.map { value in holds(value, declared: declared) } ?? true
            }
        }
    }
}
