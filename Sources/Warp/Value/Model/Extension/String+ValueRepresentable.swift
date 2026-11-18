//
//  String+ValueRepresentable.swift
//  Warp
//

import Foundation

extension String: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .string }

    @inlinable
    public init(_ value: Value) throws {
        guard case let .string(held) = value else { throw Self.refusal(of: value) }

        self = held
    }

    @inlinable
    public var value: Value { .string(self) }
}
