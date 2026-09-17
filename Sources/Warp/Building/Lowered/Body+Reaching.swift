//
//  Body+Reaching.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// The rows a body can send a run into, read off its code: every call, every
// row that answers a contract it calls through, and every closure it writes,
// whose body is a row of its own. Read once the link has answered every
// number with a row, so what comes back is rows of this link.
extension Body {
    func reaches(into rows: inout [Int]) {
        instructions.forEach { instruction in instruction.code.reaches(into: &rows) }
        result?.reaches(into: &rows)
    }
}

extension Argument {
    func reaches(into rows: inout [Int]) {
        guard case let .value(operation) = self else { return }

        operation.reaches(into: &rows)
    }
}

extension Operation {
    func reaches(into rows: inout [Int]) {
        switch self {
        // A closure held by a value stands in a body as a literal, and its
        // row is the number the link answered it with.
        case let .literal(value):
            value.closures { closure in
                rows.append(closure.number)

                return true
            }

        case .local:
            break

        case let .array(elements):
            elements.forEach { element in element.reaches(into: &rows) }

        case let .record(record):
            record.fields.forEach { field in field.reaches(into: &rows) }

        case let .closure(row, _):
            rows.append(row)

        case let .apply(callee, arguments):
            callee.reaches(into: &rows)
            arguments.forEach { _, argument in argument.reaches(into: &rows) }

        case let .cast(read, _, _):
            read.reaches(into: &rows)

        case let .block(body):
            body.reaches(into: &rows)

        case let .conditional(condition, then: then, else: otherwise):
            condition.reaches(into: &rows)
            then.forEach { instruction in instruction.code.reaches(into: &rows) }
            otherwise?.forEach { instruction in instruction.code.reaches(into: &rows) }

        case let .loop(while: condition, body: body, _, _):
            condition.reaches(into: &rows)
            body.reaches(into: &rows)

        case let .attempt(body, rescue: rescue, _):
            body.reaches(into: &rows)
            rescue.reaches(into: &rows)

        case let .call(call):
            rows.append(call.procedure)
            call.receiver?.reaches(into: &rows)
            call.arguments.forEach { argument in argument?.reaches(into: &rows) }

        // The calls beside a dispatch hand over what `arguments` holds, so
        // only the rows they reach are read off them.
        case let .dispatch(dispatch):
            dispatch.receiver.reaches(into: &rows)
            dispatch.arguments.forEach { _, argument in argument.reaches(into: &rows) }
            dispatch.calls.values.forEach { call in rows.append(call.procedure) }

        case let .leave(_, _, read):
            read?.reaches(into: &rows)
        }
    }
}

extension Linked {
    // The rows this row can send a run into: what its body names, or the
    // sends a native declared.
    var reaches: [Int] {
        switch implementation {
        case let .body(body, _):
            var rows: [Int] = []
            body.reaches(into: &rows)

            return rows

        case .native:
            return sends.map(\.row)
        }
    }

    // Which of its document's variables this row reads, by the number the
    // document gave them. What a body applies out of one is entered without
    // being named, so the closures a variable starts out holding are reached
    // through the rows that read it.
    var variables: [Int] {
        switch implementation {
        case let .body(_, frame):
            return frame.variables.map(\.variable)

        case .native:
            return []
        }
    }
}
