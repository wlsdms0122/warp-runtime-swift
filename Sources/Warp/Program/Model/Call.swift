//
//  Call.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A call: a selector and the arguments it is sent with, by position.
//
// The language has one calling type and leaves the question of what answers to
// the link. A procedure, a bundled procedure and a caller's own are not three kinds
// of expression. They are three places a selector can be found, and where it
// was found is a linkage fact rather than something the author wrote down. So
// every one of them lowers to this, and a caller adds a procedure without the
// grammar growing a case.
//
// The arguments stand at the positions of the parameters they fill. What a
// procedure is about is its first parameter, the way every other one is
// filled, so there is nothing to write in front of the selector.
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
