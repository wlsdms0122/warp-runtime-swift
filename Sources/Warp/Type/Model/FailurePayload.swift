//
//  FailurePayload.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// The fields of the envelope a rescue binds a failure as, the struct
// `Failure` the language declares in its `Prelude`. `type` and `message` are
// what every failure holds, and `details` is the map the failing procedure
// fills, of `Any` under text keys, so a rescue reaches what a failure carried
// by its key.
public enum FailurePayload {
    public static let type: Name = "type"
    public static let message: Name = "message"
    public static let details: Name = "details"
}
