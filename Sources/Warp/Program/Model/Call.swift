//
//  Call.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A message: a selector, what it is sent to, and what it is sent with.
//
// The language has one calling shape and leaves the question of what answers to
// the link. A procedure, a bundled procedure and a caller's own are not three kinds
// of expression. They are three places a selector can be found, and where it
// was found is a linkage fact rather than something the author wrote down. So
// every one of them lowers to this, and a caller adds a procedure without the
// grammar growing a case.
//
// The receiver is optional because not every message has one. `x.count` and
// `{ of: x, contains: y }` are sent *to* something; a procedure call is not. The
// language declines to invent a receiver for the ones that have none.
public struct Call: Sendable {
    // MARK: - Property
    public let receiver: Expression?
    public let selector: Name
    public let arguments: [Name: Expression]

    // MARK: - Initializer
    public init(
        receiver: Expression? = nil,
        selector: Name,
        arguments: [Name: Expression] = [:]
    ) {
        self.receiver = receiver
        self.selector = selector
        self.arguments = arguments
    }

    // MARK: - Public
    // The expression handed under a parameter's name, receiver included.
    public func handed(_ name: Name, to signature: Signature) -> Expression? {
        signature.handed(name, receiver: receiver, arguments: arguments)
    }

    // MARK: - Private
}
