//
//  Linked+Reaching.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

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
