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
    public var frames: [Frame] {
        var frames: [Frame] = []
        var link = last

        while let current = link {
            frames.append(current.frame)
            link = current.parent
        }

        return frames.reversed()
    }

    // How the place reads in a message.
    //
    //   hello.greet.many[2].send
    //
    // Names are joined with dots and occurrences are bracketed, so the spelling
    // says which parts of a place the text decided and which parts the run did.
    public var rendered: String {
        frames.reduce(into: "") { written, frame in
            switch frame {
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
    public init(frames: [Frame] = []) {
        self.last = frames.reduce(nil) { parent, frame in Link(frame, under: parent) }
    }

    private init(last: Link?) {
        self.last = last
    }

    // MARK: - Public
    public func appending(_ frame: Frame) -> Trace {
        Trace(last: Link(frame, under: last))
    }

    public static func == (lhs: Trace, rhs: Trace) -> Bool {
        lhs.frames == rhs.frames
    }

    // MARK: - Private
    private final class Link: Sendable {
        let frame: Frame
        let parent: Link?

        init(_ frame: Frame, under parent: Link?) {
            self.frame = frame
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
    // Four kinds, because there are four ways a run goes somewhere it can come back
    // from. Two of them exist only at run time — which round a loop is on, and
    // which piece of the work a concurrent word gave this closure call is — neither
    // readable from the text, and they are the difference between naming a
    // statement and naming an occurrence of one.
    enum Frame: Sendable, Equatable {
        case procedure(String)
        case statement(String)
        case round(Int)
        case piece(String)
    }
}
