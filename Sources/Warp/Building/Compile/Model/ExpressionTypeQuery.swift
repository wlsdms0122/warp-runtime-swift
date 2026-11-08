//
//  ExpressionTypeQuery.swift
//  Warp
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// What the expression standing at a place was judged to hold, asked of the
// walk that judges it, which reads it off what it passed before it. A
// `return` writes no key of its own for what it hands back, so the two stand
// at one place, and the one written there is what is handed back: the
// innermost, which the walk finishes judging first.
final class ExpressionTypeQuery {
    // MARK: - Property
    // Whether a place is the one asked about.
    private let asks: (Place) -> Bool

    // Nil until the walk judges the expression at the place.
    private(set) var answer: ExpressionType?

    // MARK: - Initializer
    init(where asks: @escaping (Place) -> Bool) {
        self.asks = asks
    }

    // MARK: - Public
    // What the expression at `place` was judged to hold, kept where `place`
    // is the one asked about and nothing there was judged before.
    func judged(_ reading: LoweredType, at place: Place, in table: LoweredTypeTable) {
        guard answer == nil, asks(place) else { return }

        answer = ExpressionType(reading, in: table)
    }

    // MARK: - Private
}
