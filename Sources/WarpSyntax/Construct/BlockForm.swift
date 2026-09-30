//
//  BlockForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// A block written as a construct: a body with its own scope, bound to a name
// like anything else.
public struct BlockForm: ConstructForm {
    // MARK: - Property
    public static let key: Name = "block"

    private let block: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.block = try BlockReader(from: decoder).block
    }

    // MARK: - Public
    public func expression(boundTo name: String?) -> Expression {
        .block(block)
    }

    // MARK: - Private
}
