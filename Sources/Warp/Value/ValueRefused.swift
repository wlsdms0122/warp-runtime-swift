//
//  ValueRefused.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A value that cannot be made or read: fields that do not fill the layout
// they are handed to, one name written twice, or a value read as a type it
// is not. It is raised at the doors values come through from outside a run
// and by a native making or reading one inside it, so the sentence says what
// was wrong with the value, and a run's refusal says where the run was.
public struct ValueRefused: WarpError {
    // MARK: - Property
    public let message: String

    public let place: Place?

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, at place: Place? = nil, trace: Trace? = nil) {
        self.message = message
        self.place = place
        self.trace = trace
    }

    // A value read as `type` that holds another.
    @usableFromInline
    init(reading type: TypeExpression, arrived value: Value) {
        self.init("\(type) is read, and \(value.nominal) arrived")
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ValueRefused {
        ValueRefused(message, at: place, trace: trace)
    }

    // MARK: - Private
}
