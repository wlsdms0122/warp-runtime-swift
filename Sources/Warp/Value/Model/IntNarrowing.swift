//
//  IntNarrowing.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// How a fraction narrows to an int. The failures are different facts. A
// fraction that is not a number holds no whole at all, digits after the point
// are not a whole number, and a whole number past the int's own edge has an
// answer no int holds. Every judge that meets a fraction names the one that
// happened, so the reading lives in one place rather than being re-derived
// beside each message.
public enum IntNarrowing {
    case int(Int)
    case notANumber
    case fractional
    case overflow

    // MARK: - Property
    // MARK: - Initializer
    public init(_ fraction: Double) {
        guard !fraction.isNaN else {
            self = .notANumber
            return
        }

        // Infinity has a whole part, and it is past every int. The overflow
        // fact, not the no-number one.
        guard fraction.isFinite else {
            self = .overflow
            return
        }

        guard fraction == fraction.rounded(.towardZero) else {
            self = .fractional
            return
        }

        guard let whole = Int(exactly: fraction) else {
            self = .overflow
            return
        }

        self = .int(whole)
    }

    // MARK: - Public
    // MARK: - Private
}
