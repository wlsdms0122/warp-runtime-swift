//
//  BodyReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// A statement sequence, read as a body.
struct BodyReader: Decodable {
    // MARK: - Property
    let body: Body

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.body = Body(try decoder.read([StatementReader].self).map(\.statement))
    }

    // MARK: - Public
    // MARK: - Private
}
