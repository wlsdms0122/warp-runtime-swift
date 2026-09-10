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

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
