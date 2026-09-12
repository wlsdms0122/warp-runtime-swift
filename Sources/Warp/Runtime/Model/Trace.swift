//
//  Trace.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Where a run is, as everything it went through to get there. Extending a
// trace links one more frame onto the one before it, so a trace a run carries
// through every statement costs one link per frame and shares the frames
// above it with every trace under them.
public struct Trace: Sendable, Equatable {
    // MARK: - Property
    // The frames from the outermost in.
    public var hops: [Hop] {
        var hops: [Hop] = []
        var link = last

        while let current = link {
            hops.append(current.hop)
            link = current.parent
        }

        return hops.reversed()
    }

    // How the place reads in a message.
    //
    //   hello.greet.many[2].call
    //
    // Names are joined with dots and occurrences are bracketed, so the spelling
    // says which parts of a place the text decided and which parts the run did.
    public var rendered: String {
        hops.reduce(into: "") { written, hop in
            switch hop {
            case let .procedure(name), let .statement(name):
                written += written.isEmpty ? name : ".\(name)"

            case let .round(index):
                written += "[\(index)]"

            case let .piece(name):
                written += "[\(name)]"
            }
        }
    }

    private let last: Link?

    // MARK: - Initializer
    public init(hops: [Hop] = []) {
        self.last = hops.reduce(nil) { parent, hop in Link(hop, under: parent) }
    }

    private init(last: Link?) {
        self.last = last
    }

    // MARK: - Public
    public func appending(_ hop: Hop) -> Trace {
        Trace(last: Link(hop, under: last))
    }

    public static func == (lhs: Trace, rhs: Trace) -> Bool {
        lhs.hops == rhs.hops
    }

    // MARK: - Private
    private final class Link: Sendable {
        let hop: Hop
        let parent: Link?

        init(_ hop: Hop, under parent: Link?) {
            self.hop = hop
            self.parent = parent
        }
    }
}

extension Trace: CustomStringConvertible {
    public var description: String { rendered }
}

public extension Trace {
    // One hop of how a run reached where it is.
    //
    // Four kinds, because there are four ways a run goes somewhere it can come
    // back from. Two of them exist only at run time (which round a loop is on,
    // and which piece of the work a concurrent procedure gave this closure call is)
    // neither readable from the text, and they are the difference between
    // naming a statement and naming an occurrence of one.
    enum Hop: Sendable, Equatable {
        case procedure(String)
        case statement(String)
        case round(Int)
        case piece(String)
    }
}
