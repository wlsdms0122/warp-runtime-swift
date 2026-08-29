//
//  CallSite.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A message plus where it was written. The location exists only to make a
// refusal answerable: a name that did not resolve, said without the path to the
// statement holding it, sends the author searching the whole document.
struct CallSite: Sendable {
    // MARK: - Property
    let dispatch: Dispatch
    let location: String

    // What each operand held where this was written — the walk's own answers,
    // carried so the check never walks a body a second time for them. A
    // call's arguments are mostly references, so without these the types a
    // declaration carries would only ever be checked against literals.
    let readings: [String: TypeExpression]
    let received: TypeExpression?

    // MARK: - Initializer
    init(
        dispatch: Dispatch,
        location: String,
        readings: [String: TypeExpression],
        received: TypeExpression?
    ) {
        self.dispatch = dispatch
        self.location = location
        self.readings = readings
        self.received = received
    }

    // MARK: - Public
    // MARK: - Private
}
