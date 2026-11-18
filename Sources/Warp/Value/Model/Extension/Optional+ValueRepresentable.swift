//
//  Optional+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Optional: ValueRepresentable where Wrapped: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .optional(Wrapped.type) }

    @inlinable
    public init(_ value: Value) throws {
        guard let payload = value.payload else {
            self = .none
            return
        }

        self = .some(try Wrapped(payload))
    }

    @inlinable
    public var value: Value {
        get throws {
            guard let wrapped = self else { return .null }

            return try wrapped.value.asSome
        }
    }
}
