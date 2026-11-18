//
//  Array+ValueRepresentable.swift
//  Warp
//

import Foundation

extension Array: ValueRepresentable where Element: ValueRepresentable {
    @inlinable
    public static var type: TypeExpression { .array(Element.type) }

    // A list in either spelling, bytes being the ints they are. An array's
    // own elements are read without the view both spellings share, which
    // asks which spelling it is at every element.
    @inlinable
    @inline(__always)
    public init(_ value: Value) throws {
        guard case let .array(elements) = value else {
            self = try Self.readingSlowPath(value)
            return
        }

        self = try elements.map { element in try Element(element) }
    }

    // The slow path of `init(_:)`: a value in the other spelling, bytes read
    // as the ints they are, and anything else refused. Out of line, so the
    // reading above stays small enough to inline into its caller.
    @inlinable
    @inline(never)
    static func readingSlowPath(_ value: Value) throws -> Self {
        guard let elements = value.elements else { throw refusal(of: value) }

        return try elements.map { element in try Element(element) }
    }

    @inlinable
    public var value: Value {
        get throws {
            .array(try map { element in try element.value })
        }
    }
}
