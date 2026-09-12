//
//  AppendEffect.swift
//  WarpStandard
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Warp

// Writing one element onto the end of an array, in place. The array is handed
// as a variable's path and written through it, so the caller's variable holds
// the longer array when the procedure answers. An effect and not a query, because
// a write is what it does.
struct AppendEffect: Effect {
    // What this takes: the variable written into, and the element written
    // onto its end.
    enum Parameters: Int, ParameterSet {
        case to
        case value

        var name: Name {
            switch self {
            case .to:
                return "to"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .to:
                return Parameter(type: .inout(.array(.parameter(name: "Element"))))

            case .value:
                return Parameter(type: .parameter(name: "Element"))
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .array(elements) = try invocation.held(.to) else {
            throw ExecutionError("append writes onto an array, and 'to' holds something else")
        }

        try invocation.write(.to, .array(elements + [invocation[.value]]))

        return .null
    }

    // MARK: - Private
}
