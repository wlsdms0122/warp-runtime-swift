//
//  Native.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// A procedure implemented in native code: one that answers without running
// anything, or one that reaches outside the run.
//
// What such a procedure declares about itself is read here. A body's purity,
// isolation and failing are what its code turns out to do and a link works
// them out; a native says, and the row a compile settles records what it said.
enum Native: Sendable {
    case query(any Query)
    case effect(any Effect)

    // MARK: - Property
    // Answers without running, which is what lets it be asked inside a
    // condition and while a constant settles.
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
    // procedure reading an argument nobody sent it.
    var parameters: [(position: Int, name: Name)] {
        switch self {
        case let .query(query):
            return places(of: query)

        case let .effect(effect):
            return places(of: effect)
        }
    }

    // The procedures it sends, in the places it names them at.
    var imports: [(position: Int, selector: Name)] {
        switch self {
        case let .query(query):
            return sends(of: query)

        case let .effect(effect):
            return sends(of: effect)
        }
    }

    // The procedures it sends as a link compares them: in position order,
    // spellings only. A row records these where it was compiled, and a procedure
    // brought later naming others sends where the row does not stand.
    var sending: [Name] {
        imports.sorted { left, right in left.position < right.position }.map(\.selector)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // Generic, so the procedure's own parameter type has a name here. Handing an
    // existential to a generic function opens it.
    private func places<P: NativeProcedure>(of procedure: P) -> [(position: Int, name: Name)] {
        P.Parameters.allCases.map { key in (position: key.position, name: key.name) }
    }

    private func sends<P: NativeProcedure>(of procedure: P) -> [(position: Int, selector: Name)] {
        P.Imports.allCases.map { key in (position: key.position, selector: key.selector) }
    }
}
