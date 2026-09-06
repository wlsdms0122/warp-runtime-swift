//
//  CallSite.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A message plus where it was written. The place exists only to make a refusal
// answerable: a name that did not resolve, said without the path to the
// statement holding it, sends the author searching the whole document.
struct CallSite: Sendable {
    // MARK: - Property
    let call: Call
    let place: Place

    // The declaration the selector names, found by the walk that gathered
    // this call, so nothing has to find it again.
    let callee: Symbol

    // What each operand held where this was written. The walk's own answers,
    // carried so the check never walks a body a second time for them. A call's
    // arguments are mostly references, so without these the types a declaration
    // carries would only ever be checked against literals.
    let readings: [Name: Shape]
    let received: Shape?

    // MARK: - Initializer
    init(
        call: Call,
        place: Place,
        callee: Symbol,
        readings: [Name: Shape],
        received: Shape?
    ) {
        self.call = call
        self.place = place
        self.callee = callee
        self.readings = readings
        self.received = received
    }

    // MARK: - Public
    // MARK: - Private
}
