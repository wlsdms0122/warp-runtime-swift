//
//  Resolving.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// How a number written in a body finds its row.
//
// A body carries the numbers its own document gave, so which row a number
// stands for is a question about the document the body came from. A link
// answers it once by relocating every body into its own table; what runs while
// a link is still being made was never relocated, so it answers it call by
// call instead.
enum Resolving: Sendable {
    // The numbers are already rows. What a link relocated stands in the table
    // that relocated it.
    case rows

    // What each document's numbers stand for, by the document and then by the
    // number.
    case documents([[Int]])

    // MARK: - Public
    func row(_ number: Int, from origin: Int) -> Int {
        switch self {
        case .rows:
            return number

        case let .documents(held):
            return held[origin][number]
        }
    }
}
