//
//  Native.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// A word implemented in native code: one that answers without running
// anything, or one that reaches outside the run.
//
// What such a word declares about itself is read here. A body's purity,
// isolation and failing are what its code turns out to do and a link works
// them out; a native says, and the row a compile settles records what it said.
enum Native: Sendable {
    case query(any Query)
    case effect(any Effect)

    // MARK: - Property
    // Answers without running, which is what lets it be asked inside a
    // condition and inside a path.
    var purity: Purity {
        switch self {
        case .query:
            return .pure

        case .effect:
            return .unstated
        }
    }

    // Touches no name another body could touch at the same time.
    var isolation: Isolation {
        switch self {
        case let .query(query):
            return query.isolated ? .isolated : .unstated

        case let .effect(effect):
            return effect.isolated ? .isolated : .unstated
        }
    }

    // What may come out of it when the work goes wrong.
    var failing: Failing {
        switch self {
        case let .query(query):
            return query.failing

        case let .effect(effect):
            return effect.failing
        }
    }

    // The places it reads its arguments at, with the name each place stands
    // under. Its own, so a declaration whose parameters stand elsewhere is a
    // word reading an argument nobody sent it.
    var parameters: [(position: Int, name: Name)] {
        switch self {
        case let .query(query):
            return places(of: query)

        case let .effect(effect):
            return places(of: effect)
        }
    }

    // The words it sends, in the places it names them at.
    var imports: [(position: Int, selector: Name)] {
        switch self {
        case let .query(query):
            return sends(of: query)

        case let .effect(effect):
            return sends(of: effect)
        }
    }

    // The words it sends as a link compares them: in position order,
    // spellings only. A row records these where it was compiled, and a word
    // brought later naming others sends where the row does not stand.
    var sending: [Name] {
        imports.sorted { left, right in left.position < right.position }.map(\.selector)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private var kind: Any.Type {
        switch self {
        case let .query(query):
            return type(of: query)

        case let .effect(effect):
            return type(of: effect)
        }
    }
    // Generic, so the word's own parameter type has a name here. Handing an
    // existential to a generic function opens it.
    private func places<W: Word>(of word: W) -> [(position: Int, name: Name)] {
        W.Parameters.allCases.map { key in (position: key.position, name: key.name) }
    }

    private func sends<W: Word>(of word: W) -> [(position: Int, selector: Name)] {
        W.Imports.allCases.map { key in (position: key.position, selector: key.selector) }
    }
}
