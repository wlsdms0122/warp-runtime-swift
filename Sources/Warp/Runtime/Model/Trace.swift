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
public struct Trace: Sendable, Equatable, CustomStringConvertible {
    // One hop of how a run reached where it is.
    //
    // Five kinds, because there are five ways a run goes somewhere it can come
    // back from. Two of them exist only at run time (which round a loop is on,
    // and which piece of the work a concurrent procedure gave this closure call is)
    // neither readable from the text, and they are the difference between
    // naming a statement and naming an occurrence of one.
    //
    // A closure has no spelling of its own: it is the nth one the named
    // declaration wrote, and that pair is what the hop carries.
    public enum Hop: Sendable, Equatable {
        case procedure(String)
        case closure(of: String, nth: Int)
        case statement(String)
        case round(Int)
        case piece(String)

        // How the hop reads on its own, which is also what a refusal calls
        // the body it enters.
        var rendered: String {
            switch self {
            case let .procedure(name), let .statement(name): name
            case let .closure(writer, nth): "\(writer).closure[\(nth)]"
            case let .round(index): "[\(index)]"
            case let .piece(name): "[\(name)]"
            }
        }
    }

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
    //   hello.greet.closure[0].say
    //
    // Names are joined with dots and what tells one from another of the same
    // name is bracketed: which round of a loop, which piece of a fan-out,
    // which of the closures a declaration wrote, and which statement where
    // the text gave it no name.
    public var rendered: String {
        hops.reduce(into: "") { written, hop in
            switch hop {
            case .procedure, .closure, .statement:
                written += written.isEmpty ? hop.rendered : ".\(hop.rendered)"

            case .round, .piece:
                written += hop.rendered
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

    public var description: String { rendered }

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
