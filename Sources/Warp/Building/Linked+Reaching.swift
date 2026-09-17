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
    // The rows this body reaches by number, and the rows the closures its
    // values hold stand in.
    var reaches: (rows: [Int], held: [Linked]) {
        var rows: [Int] = []
        var held: [Linked] = []

        walk { node in
            node.reaches(into: &rows, holding: &held)

            return true
        }

        return (rows, held)
    }
}

extension Body.Node {
    // The rows this one node sends a run into, apart from what nests in it,
    // and the rows the closures its values hold stand in. A closure a value
    // holds was answered by the link before this is asked, so one holding
    // no row is none this walk was handed.
    func reaches(into rows: inout [Int], holding held: inout [Linked]) {
        guard case let .operation(operation) = self else { return }

        switch operation {
        case let .literal(value):
            value.closures { closure in closure.linked.map { linked in held.append(linked) } }

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
    // What this row can send a run into: what its body names, the closures
    // the variables it reads start out holding, since a body applies what it
    // reads out of one without naming it, or the sends a native declared.
    // The variables are its own document's, by the number it gave them.
    func reaches(starting variables: [(name: Name, value: Value)]) -> (rows: [Int], held: [Linked]) {
        switch implementation {
        case let .body(body, frame):
            var reach = body.reaches

            for (variable, _) in frame.variables {
                variables[variable].value.closures { closure in closure.linked.map { linked in reach.held.append(linked) } }
            }

            return reach

        case .native:
            return (sends.map(\.row), [])
        }
    }
}

extension Array where Element == Linked {
    // Which rows a run entering at one can reach: what each row reaches,
    // transitively, by the rows themselves. Every number met is a row of
    // this table, since the link answered each one before the table was
    // handed over, and every row a closure holds is one of these, since the
    // link relocates a row once. The variables are every document's, by the
    // document and then by the number it gave them.
    func reached(
        from start: Int,
        starting variables: [[(name: Name, value: Value)]],
        in documents: [Place.Document]
    ) throws -> Set<ObjectIdentifier> {
        var reached: Set<ObjectIdentifier> = []
        var frontier = [self[start]]

        while let next = frontier.popLast() {
            guard reached.insert(ObjectIdentifier(next)).inserted else { continue }

            // A row of this table stands in a document of this link. One that
            // does not is a row a closure brought in from some other table.
            guard variables.indices.contains(next.origin) else {
                throw BuildError.unjudged(
                    "a closure holding a row of some other table",
                    at: .procedure(next.label.spelling, in: documents.indices.contains(next.origin) ? documents[next.origin] : .assembled)
                )
            }

            let reach = next.reaches(starting: variables[next.origin])

            frontier.append(contentsOf: reach.rows.map { row in self[row] })
            frontier.append(contentsOf: reach.held)
        }

        return reached
    }
}
