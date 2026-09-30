//
//  RecoverableFailure.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A failure of the work itself. The data wasn't there, the world didn't
// cooperate. `attempt` absorbs these; author mistakes (type misuse, contract
// violations) deliberately do not carry the marker, so they surface instead.
//
// It lives beside the runtime because it is `attempt`'s half of a contract, not
// a taxonomy of errors: the executor is the only thing that reads it, and what
// declares it is whatever can fail while a body runs. Three constructs here,
// and a caller's own procedures out beyond the package.
//
// While a rescue runs, the failure exists as a value: the executor binds
// `payload` under the failed statement's id, so a rescue body can read what
// went wrong through `<id>.message` and, under `<id>.details`, whatever else
// that failure carries. The envelope is the same for every failure and what
// rides inside it is the failing procedure's own. The runtime owns the
// mechanism, the error owns the vocabulary.
public protocol RecoverableFailure: WarpError {
    // What this failure names itself. `aborted`, `concurrent_failed`.
    var type: String { get }

    // Whatever this failure carries beyond the envelope. Empty for most; a
    // `concurrent_failed` keys every piece's reason by the piece.
    var details: [Name: Value] { get }
}

public extension RecoverableFailure {
    var details: [Name: Value] { [:] }

    // Deliberately not a protocol requirement: the type is assembled here and
    // nowhere else, so a conformance cannot hand over a payload the link's
    // declaration does not describe. A declaration a conformance could quietly
    // break is a promise rather than a fact, and this is a promise the type
    // system keeps.
    //
    // What a failure carries rides in a box of its own rather than beside the
    // envelope's names, so no failure can redefine the field naming what
    // happened by adding a field.
    var payload: Value {
        .dictionary([
            "type": .string(type),
            "message": .string(message),
            "details": .dictionary(details)
        ])
    }
}
