//
//  Linked+Reaching.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// The rows a body can send a run into, read off its code: every call, every
// row that answers a contract it calls through, and every closure it writes,
// whose body is a row of its own. Read once the link has answered every
// number with a row, so what comes back is rows of this link. A closure a
// value holds is spelled by its writer, and the link says which row that is.
extension Body {
    // The rows this body reaches, with every closure a value holds answered
    // by the link.
    func reaches(answering row: (Closure) throws -> Int) rethrows -> [Int] {
        var rows: [Int] = []
        var held: [Closure] = []

        walk { node in
            node.reaches(into: &rows, holding: &held)

            return true
        }

        return rows + (try held.map(row))
    }
}

extension Body.Node {
    // The rows this one node sends a run into, apart from what nests in it,
    // and the closures the values it holds hold.
    func reaches(into rows: inout [Int], holding held: inout [Closure]) {
        guard case let .operation(operation) = self else { return }

        switch operation {
        // A closure held by a value stands in a body as a literal.
        case let .literal(value):
            value.closures { closure in held.append(closure) }

        case let .closure(row, _):
            rows.append(row)

        case let .call(call):
            rows.append(call.procedure)

        case let .dispatch(dispatch):
            dispatch.calls.values.forEach { call in rows.append(call.procedure) }

        case .local, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
            break
        }
    }
}

extension Linked {
    // The rows this row can send a run into: what its body names, the
    // closures the variables it reads start out holding, since a body applies
    // what it reads out of one without naming it, or the sends a native
    // declared. The variables are its own document's, by the number it gave
    // them.
    func reaches(
        starting variables: [(name: Name, value: Value)],
        answering row: (Closure, Int) throws -> Int
    ) rethrows -> [Int] {
        switch implementation {
        case let .body(body, frame):
            var held: [Closure] = []

            for (variable, _) in frame.variables {
                variables[variable].value.closures { closure in held.append(closure) }
            }

            return try body.reaches { closure in try row(closure, origin) }
                + (try held.map { closure in try row(closure, origin) })

        case .native:
            return sends.map(\.row)
        }
    }
}

extension Array where Element == Linked {
    // Which rows a run entering at one can reach: what each row reaches,
    // transitively. Every number met is a row of this table, since the link
    // answered each one before the table was handed over, and a closure a
    // value holds is answered by the link the same way. The variables are
    // every document's, by the document and then by the number it gave them.
    func reached(
        from start: Int,
        starting variables: [[(name: Name, value: Value)]],
        answering row: (Closure, Int) throws -> Int
    ) rethrows -> Set<Int> {
        var reached: Set<Int> = []
        var frontier = [start]

        while let next = frontier.popLast() {
            guard reached.insert(next).inserted else { continue }

            frontier.append(contentsOf: try self[next].reaches(starting: variables[self[next].origin], answering: row))
        }

        return reached
    }
}
