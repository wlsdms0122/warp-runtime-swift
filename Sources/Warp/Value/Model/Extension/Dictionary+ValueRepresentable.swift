//
//  Dictionary+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Dictionary: ValueRepresentable where Key: ValueRepresentable, Value: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .dictionary(key: Key.type, value: Value.type) }

    @inlinable
    public init(_ value: Warp.Value) throws {
        guard case let .dictionary(dictionary) = value else { throw Self.refusal(of: value) }

        self = try Dictionary(
            dictionary.entries.map { entry in (try Key(entry.key), try Value(entry.value)) },
            uniquingKeysWith: { _, later in later }
        )
    }

    @inlinable
    public var value: Warp.Value {
        get throws {
            .dictionary(try Warp.Value.Dictionary(map { key, value in (key: try key.value, value: try value.value) }))
        }
    }
}
