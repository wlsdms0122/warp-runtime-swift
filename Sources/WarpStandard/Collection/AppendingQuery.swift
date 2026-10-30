//
//  AppendingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The elements with one more at the end, as a new array.
struct AppendingQuery: Query {
    // What this takes: the array, and one more element of its element type.
    enum Parameters: Int, ParameterSet {
        case array
        case element

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .array:
                return Parameter(name: "array", type: .array(.parameter(name: "Element")))

            case .element:
                return Parameter(name: "element", type: .parameter(name: "Element"))
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        // Returned in the spelling the collection arrived in, so a compact one
        // stays compact until an element that is not a byte is put among them,
        // which `adding` reads for itself.
        guard let appended = question[.array].adding(question[.element], atFront: false) else {
            throw ExecutionError("Standard.Collection.appending asks an Array")
        }

        return appended
    }

    // MARK: - Private
}
