//
//  Call.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A call: the procedure it names, under `selector`, and its arguments by
// position.
//
// The language has one calling type and leaves which declaration answers to
// the build. A procedure a document declares, one a bundle declares and a
// host's own are three places a name can be found, not three kinds of
// expression, so every one of them lowers to this and a host adds a
// procedure without the grammar growing a case.
//
// The arguments stand at the positions of the parameters they fill, the first
// one included, so there is nothing to write in front of the name.
public struct Call: Sendable {
    // MARK: - Property
    public let selector: Name
    public let arguments: [Expression]

    // MARK: - Initializer
    public init(selector: Name, arguments: [Expression] = []) {
        self.selector = selector
        self.arguments = arguments
    }

    // MARK: - Public
    // MARK: - Private
}
