//
//  BodyReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// A statement sequence, read as a body.
public struct BodyReader: Decodable {
    // MARK: - Property
    public let body: Body

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // Each statement names itself as it is read, so a refusal arrives
        // already wearing the name the author knows it by.
        self.body = Body(try decoder.read([StatementReader].self).map(\.statement))
    }

    // MARK: - Public
    // MARK: - Private
}
