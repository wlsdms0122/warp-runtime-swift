//
//  SequenceQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Reading an array without saying where. Each takes nothing, so each is
// reachable from a path. `items.first` is the shape these exist for.
public struct SequenceQuery: Query {
    public enum Reading: Sendable {
        case first
        case last
        case reversed
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is, and `first` reads one
        // element of a compact spelling without unpacking the rest.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        switch reading {
        // An empty array has no first, and having none is absence rather than
        // failure. The same answer a missing field gives.
        case .first:
            return elements.first

        case .last:
            return elements.last

        // The same elements in the other order, said by position, so the
        // spelling they arrived in is the spelling they leave in, and a compact
        // one is turned around as what it holds rather than read out as values
        // and written back.
        case .reversed:
            return receiver.elements(at: (0 ..< elements.count).reversed())
        }
    }

    // MARK: - Private
}
