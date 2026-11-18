//
//  RecoverableFailure.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A failure of the work itself. The data wasn't there, the world didn't
// cooperate. `try` absorbs these; author mistakes (type misuse, contract
// violations) do not carry the marker, so they surface instead.
//
// While a catch runs, the failure is a value: the run binds `payload` under
// the try's name, so a catch body reads `<name>.message` and, in the dictionary
// `<name>.details`, whatever else that failure carries.
public protocol RecoverableFailure: WarpError {
    // What this failure names itself.
    var type: String { get }

    // Whatever this failure carries beyond the envelope, under string keys.
    var details: Value.Dictionary { get }
}

public extension RecoverableFailure {
    var details: Value.Dictionary { Value.Dictionary([:]) }

    // Built here and not by a conformer, so every payload is the struct
    // `Failure` the language declares.
    var payload: Value {
        .struct(
            Struct(
                name: TypeSpelling.failure,
                [
                    FailurePayload.type: .string(type),
                    FailurePayload.message: .string(message),
                    FailurePayload.details: .dictionary(details)
                ]
            )
        )
    }
}
