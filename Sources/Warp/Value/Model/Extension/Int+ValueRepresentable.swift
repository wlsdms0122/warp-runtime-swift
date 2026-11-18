//
//  Int+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Int: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .int }

    @inlinable
    public init(_ value: Value) throws {
        guard case let .int(held) = value else { throw Self.refusal(of: value) }

        self = held
    }

    @inlinable
    public var value: Value { .int(self) }
}
