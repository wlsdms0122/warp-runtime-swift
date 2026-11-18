//
//  UppercasedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The string in upper case.
struct UppercasedQuery: Computation {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func compute(_ arguments: Arguments<Self>) throws -> Value {
        guard case let .string(text) = arguments[.text] else {
            throw RunRefused("Standard.Text.uppercased asks a String")
        }

        return .string(text.uppercased())
    }

    // MARK: - Private
}
