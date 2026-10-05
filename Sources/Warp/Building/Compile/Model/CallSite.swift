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

    // What each operand held where this was written, as one type. The walk's
    // own answers, carried so the check never walks a body a second time for
    // them. A call's arguments are mostly references, so without these the
    // types a declaration carries would only ever be checked against
    // literals. By position, the order the arguments were written in.
    let readings: [LoweredType]

    // What an operand that is a list or record literal holds part by part,
    // by position, where its reading does not say.
    let shapes: [Int: LiteralShape]

    // MARK: - Initializer
    init(
        call: Call,
        place: Place,
        readings: [LoweredType],
        shapes: [Int: LiteralShape]
    ) {
        self.call = call
        self.place = place
        self.readings = readings
        self.shapes = shapes
    }

    // MARK: - Public
    // MARK: - Private
}
