//
//  Bool+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Bool: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .bool }

    @inlinable
    public init(_ value: Value) throws {
        guard case let .bool(held) = value else { throw Self.refusal(of: value) }

        self = held
    }

    @inlinable
    public var value: Value { .bool(self) }
}
