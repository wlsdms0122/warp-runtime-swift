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
    var reaches: Reach {
        var reach = Reach()

        walk { node in
            node.reaches(into: &reach)

            return true
        }

        return reach
    }
}

// What a body reaches: rows by number, and closures a value holds.
struct Reach {
    var rows: [Int] = []
    var held: [Closure] = []

    mutating func reach(_ value: Value) {
        value.closures { closure in held.append(closure) }
    }
}

extension Body.Node {
    // The rows this one node sends a run into, apart from what nests in it.
    func reaches(into reach: inout Reach) {
        guard case let .operation(operation) = self else { return }

        switch operation {
        // A closure held by a value stands in a body as a literal.
        case let .literal(value):
            reach.reach(value)

        case let .closure(row, _):
            reach.rows.append(row)

        case let .call(call):
            reach.rows.append(call.procedure)

        case let .dispatch(dispatch):
            dispatch.calls.values.forEach { call in reach.rows.append(call.procedure) }

        case .local, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
            break
        }
    }
}

extension Linked {
    // What this row can send a run into: what its body names, the closures
    // the variables it reads start out holding, since a body applies what it
    // reads out of one without naming it, or the sends a native declared. The
    // variables are its own document's, by the number it gave them.
    func reaches(starting variables: [(name: Name, value: Value)]) -> Reach {
        switch implementation {
        case let .body(body, frame):
            var reach = body.reaches

            for (variable, _) in frame.variables {
                reach.reach(variables[variable].value)
            }

            return reach

        case .native:
            return Reach(rows: sends.map(\.row))
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
        answering row: (Closure) -> Int?
    ) -> Set<Int> {
        var reached: Set<Int> = []
        var frontier = [start]

        while let next = frontier.popLast() {
            guard reached.insert(next).inserted else { continue }

            let reach = self[next].reaches(starting: variables[self[next].origin])

            frontier.append(contentsOf: reach.rows)
            frontier.append(contentsOf: reach.held.compactMap(row))
        }

        return reached
    }
}
