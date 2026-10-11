//
//  FailurePayload.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// The envelope a rescue binds a failure as, said once for the type the build
// holds the rescue's name to and for the value the run binds there. `type`
// and `message` are what every failure holds, and `details` is the box the
// failing procedure fills: a dictionary of `Any`, so a rescue reaches what a
// failure carried by naming it.
public enum FailurePayload {
    public static let type: Name = "type"
    public static let message: Name = "message"
    public static let details: Name = "details"

    public static let declared = TypeExpression.record([
        type: .string,
        message: .string,
        details: .dictionary(key: .string, value: .any)
    ])
}
