//
//  RecoverableFailure.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A failure of the work itself — the data wasn't there, the world didn't
// cooperate. `attempt` absorbs these; author mistakes (shape misuse, contract
// violations) deliberately do not carry the marker, so they surface instead.
//
// It lives beside the runtime because it is `attempt`'s half of a contract, not
// a taxonomy of errors: the executor is the only thing that reads it, and what
// declares it is whatever can fail while a body runs — three constructs here,
// and a caller's own words out beyond the package.
//
// While a rescue runs, the failure exists as a value: the executor binds
// `payload` under the failed statement's id, so a rescue body can read what went
// wrong through `<id>.message` and whatever else that failure carries. Every
// payload holds at least `type` and `message`; each error adds its own fields on
// top — the runtime owns the mechanism, the error owns the vocabulary.
public protocol RecoverableFailure: WarpError {
    // One word naming what happened — `aborted`, `concurrent_failed`.
    var type: String { get }

    // Whatever this failure carries beyond the two every failure holds. Empty
    // for most; a `concurrent_failed` keys every piece's reason by the piece.
    var details: [String: Value] { get }
}

public extension RecoverableFailure {
    var details: [String: Value] { [:] }

    // Deliberately not a protocol requirement: the shape is assembled here and
    // nowhere else, so a conformance cannot hand over a payload without `type`
    // or `message`. The link declares this shape and holds a rescue's name to
    // it, and a declaration a conformance could quietly break is a promise
    // rather than a fact — this is a promise the type system keeps.
    //
    // It replaces a check at the other end: the run used to judge the payload
    // as the rescue began, which caught a broken conformance only on the runs
    // that reached it, and turned a recoverable failure into one nothing could
    // catch at the moment something wanted to catch it.
    // The two the link declares win any collision: they are what every
    // rescue is promised, so a failure that also put a `type` in `details`
    // does not get to redefine the word naming what happened. What it wanted
    // to say belongs under a name of its own.
    var payload: Value {
        .record(
            Record(
                name: nil,
                details.merging([
                    "type": .string(type),
                    "message": .string(message),
                ]) { _, core in core }
            )
        )
    }
}

// The shape the sentence above promises, said once as a type so the link can
// hold the rescue's name to it. Before this it read `any`, which threw the
// promise away: a rescue could reach anything and be judged on nothing.
//
// Only the guaranteed core is here. What an error adds on top is real but
// unnamed, so it is read the way any data past a declaration is — by naming
// the shape, with `as`.
public enum FailurePayload {
    public static let declared = TypeExpression.record([
        "type": .string,
        "message": .string,
    ])
}
