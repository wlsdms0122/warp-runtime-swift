//
//  Implementation.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How a procedure does what it declares. A body of statements, or native code.
//
// This is the whole of what separates a native word from a procedure: which
// language the body is written in. Both are the same concept answered two ways,
// so they share one container.
//
// There is one kind of declaration, and this is the axis it varies on. A module
// of native words links like any other, and a document calling one is doing what
// a document calling a procedure does.
public enum Implementation: Sendable {
    case body(Block)

    // Answers without running anything. Pure and synchronous, which is what
    // lets it be asked inside a condition and inside a path.
    case query(any Query)

    // Answers by reaching outside the run. Asynchronous, so it cannot be asked
    // where a value is merely read.
    case effect(any Effect)

    // MARK: - Property
    // Whether this answers without running. For a body it is not knowable from
    // the case alone (what it calls decides) so the linker computes it and this
    // says only what a native declares about itself.
    public var isNativelyPure: Bool? {
        switch self {
        case .query:
            return true

        case .effect:
            return false

        case .body:
            return nil
        }
    }

    // Whether this touches no name another body could touch at the same time.
    // A native says so about itself; for a body what it writes and what it
    // calls decide, so the linker works it out and this answers only for the
    // two that declare.
    public var isNativelyIsolated: Bool? {
        switch self {
        case let .query(query):
            return query.isolated

        case let .effect(effect):
            return effect.isolated

        case .body:
            return nil
        }
    }

    // What may come out of this when the work goes wrong. A native says so
    // about itself; for a body what it casts, calls and rescues decides, so
    // the linker works it out and this answers only for the two that declare.
    public var nativelyFailing: Failing? {
        switch self {
        case let .query(query):
            return query.failing

        case let .effect(effect):
            return effect.failing

        case .body:
            return nil
        }
    }

    // The places a native word reads its arguments at, with the name each
    // place stands under. Nil for a body, which reads the names its own
    // declaration gave it.
    var nativeParameters: [(position: Int, name: Name)]? {
        switch self {
        case let .query(query):
            return places(of: query)

        case let .effect(effect):
            return places(of: effect)

        case .body:
            return nil
        }
    }

    // The words a native word sends, in the places it names them at. Nil for
    // a body, whose sends are read off its text.
    var nativeImports: [(position: Int, selector: Name)]? {
        switch self {
        case let .query(query):
            return sends(of: query)

        case let .effect(effect):
            return sends(of: effect)

        case .body:
            return nil
        }
    }

    public var block: Block? {
        guard case let .body(block) = self else { return nil }

        return block
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // Generic, so the word's own parameter type has a name here. Handing an
    // existential to a generic function opens it.
    private func places(of word: some Word) -> [(position: Int, name: Name)] {
        places(of: type(of: word))
    }

    private func places<W: Word>(of word: W.Type) -> [(position: Int, name: Name)] {
        W.Parameters.allCases.map { key in (position: key.position, name: key.name) }
    }

    private func sends(of word: some Word) -> [(position: Int, selector: Name)] {
        sends(of: type(of: word))
    }

    private func sends<W: Word>(of word: W.Type) -> [(position: Int, selector: Name)] {
        W.Imports.allCases.map { key in (position: key.position, selector: key.selector) }
    }
}
