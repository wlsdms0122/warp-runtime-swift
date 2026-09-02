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

    // Whether a body writes only names it declares — its parameters and the
    // variables it introduces, at any depth — and calls only isolated
    // declarations. A name written that was not declared here is a name the
    // body reached from outside: a module variable, or one a closure captured.
    func isIsolated(
        _ block: Block,
        declaring parameters: Set<String>,
        given isolated: Set<String>,
        signatures: [String: Signature]
    ) -> Bool {
        var declared = parameters

        declared.formUnion(block.declaredVariables)

        return block.body.allSatisfy { statement in
            writesOnlyDeclared(statement, declared: declared)
                && isIsolated(statement.expression, declared: declared, given: isolated, signatures: signatures)
        }
            && (block.result.map { result in
                isIsolated(result, declared: declared, given: isolated, signatures: signatures)
            } ?? true)
    }

    // MARK: - Private
    private func writesOnlyDeclared(_ statement: Statement, declared: Set<String>) -> Bool {
        guard case let .assignment(path)? = statement.binding, let head = path.head else { return true }

        return declared.contains(head)
    }

    private func isIsolated(
        _ expression: Expression,
        declared: Set<String>,
        given isolated: Set<String>,
        signatures: [String: Signature]
    ) -> Bool {
        func inner(_ expression: Expression) -> Bool {
            isIsolated(expression, declared: declared, given: isolated, signatures: signatures)
        }

        func inner(_ body: [Statement]) -> Bool {
            body.allSatisfy { statement in
                writesOnlyDeclared(statement, declared: declared) && inner(statement.expression)
            }
        }

        func inner(_ block: Block) -> Bool {
            inner(block.body) && (block.result.map(inner) ?? true)
        }

        switch expression {
        case .literal, .reference:
            return true

        case .invoke:
            return false

        case let .cast(value, _, _):
            return inner(value)

        case let .array(array):
            return array.allSatisfy(inner)

        case let .record(record):
            return record.values.allSatisfy(inner)

        // A closure written here is judged for its own isolation when it is
        // made; making it touches nothing.
        case .closure:
            return true

        case let .dispatch(dispatch):
            guard isolated.contains(dispatch.selector) else { return false }

            guard let signature = signatures[dispatch.selector] else { return false }

            for (name, parameter) in signature.parameters where parameter.declared.isInout {
                let argument = name == signature.receiver
                    ? dispatch.receiver ?? dispatch.arguments[name]
                    : dispatch.arguments[name]

                guard case let .reference(path)? = argument, let head = path.head else { continue }

                guard declared.contains(head) else { return false }
            }

            return (dispatch.receiver.map(inner) ?? true)
                && dispatch.arguments.values.allSatisfy(inner)

        case let .block(block):
            return inner(block)

        case let .conditional(condition, then, otherwise):
            return inner(condition) && inner(then) && (otherwise.map(inner) ?? true)

        case let .loop(condition, body, _):
            return inner(condition) && inner(body)

        case let .iteration(collection, body, _):
            return inner(collection) && inner(body)

        case let .attempt(body, rescue, _):
            return inner(body) && inner(rescue)

        case let .leave(leave):
            return leave.value.map(inner) ?? true
        }
    }

}

extension Block {
    // Every variable a body introduces, at any depth, and every parameter of a
    // closure written inside it. Reading through nested blocks and closures,
    // because a write anywhere inside this body to a name declared anywhere
    // inside it is this body's own business.
    var declaredVariables: Set<String> {
        var names: Set<String> = []

        func walk(_ statements: [Statement]) {
            for statement in statements {
                if case let .variable(name)? = statement.binding { names.insert(name) }
                walk(statement.expression)
            }
        }

        func walk(_ block: Block) {
            walk(block.body)
            block.result.map(walk)
        }

        func walk(_ expression: Expression) {
            switch expression {
            case .literal, .reference, .leave:
                break

            case let .cast(value, _, _):
                walk(value)

            case let .array(array):
                array.forEach(walk)

            case let .record(record):
                record.values.forEach(walk)

            case let .closure(procedure):
                names.formUnion(procedure.signature.parameters.keys)
                procedure.block.map(walk)

            case let .invoke(callee, arguments):
                walk(callee)
                arguments.values.forEach(walk)

            case let .dispatch(dispatch):
                dispatch.receiver.map(walk)
                dispatch.arguments.values.forEach(walk)

            case let .block(block):
                walk(block)

            case let .conditional(condition, then, otherwise):
                walk(condition)
                walk(then)
                otherwise.map(walk)

            case let .loop(condition, body, _):
                walk(condition)
                walk(body)

            case let .iteration(collection, body, _):
                walk(collection)
                walk(body)

            case let .attempt(body, rescue, _):
                walk(body)
                walk(rescue)
            }
        }

        walk(self)

        return names
    }
}
