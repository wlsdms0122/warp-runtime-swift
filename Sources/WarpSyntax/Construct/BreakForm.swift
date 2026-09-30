//
//  BreakForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `break:`. Leaves a loop: the nearest one, or the one it names. The other
// two leave forms are `ReturnForm` and `ContinueForm`.
public struct BreakForm: ConstructForm {
    // MARK: - Property
    public static let key: Name = "break"

    private let target: Name?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.target = try Self.target(from: decoder, called: Self.key)
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .leave(Leave(reach: .construct, target: target))
    }

    // Which loop, or nothing for the nearest. A loop answers what it was going
    // to answer, so there is nothing to carry and what stands here is a name.
    static func target(from decoder: Decoder, called key: Name) throws -> Name? {
        switch try ValueReader(from: decoder).value {
        case .null:
            return nil

        case let .string(name):
            return try Name.read(name, at: decoder.steps)

        case let other:
            throw ReadingError(
                "\(key) takes the name of a loop, or nothing for the"
                    + " nearest one. Got \(other.type)",
                at: decoder.steps
            )
        }
    }

    // MARK: - Private
}
