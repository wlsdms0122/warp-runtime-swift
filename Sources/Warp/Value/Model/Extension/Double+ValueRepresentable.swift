//
//  Double+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Double: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .double }

    @inlinable
    public init(_ value: Value) throws {
        guard case let .double(held) = value else { throw Self.refusal(of: value) }

        self = held
    }

    @inlinable
    public var value: Value { .double(self) }
}
