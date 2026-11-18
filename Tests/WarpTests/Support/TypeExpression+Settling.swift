//
//  TypeExpression+Settling.swift
//  WarpTests
//
//  Created by JSilver on 10/10/26.
//

import Foundation
@testable import Warp

extension TypeExpression {
    // A value from outside fitted and judged at this type, by the door rule a
    // host's value meets, over the table the type's names stand in.
    func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in types: TypeTable = .empty
    ) throws -> Value {
        try lowered(in: types.loweredTypes).settling(outside: value, at: path(), in: types.loweredTypes)
    }
}
