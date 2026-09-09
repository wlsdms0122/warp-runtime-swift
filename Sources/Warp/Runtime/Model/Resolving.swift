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
    // number. A number the link found no row for stands as nothing: a document
    // numbers every bare spelling its paths step to, and a step onto a field
    // reaches no declaration, so a numbering holds names no body ever calls.
    case documents([Int: [Int?]])

    // MARK: - Public
    // The same reading with one document's closure rows written in, for code
    // lowered beside that document and run at once. What folds numbers its own
    // closures after the document's, so the rows it took go on the end.
    func holding(_ closures: [Int], of origin: Int) -> Resolving {
        guard case let .documents(held) = self, !closures.isEmpty else { return self }

        var view = held[origin] ?? []

        // A closure this run made stands where the document's own end, so a
        // view shorter than that is filled out before they are written on.
        view.append(contentsOf: closures.map { row in row })

        return .documents(held.merging([origin: view]) { _, folded in folded })
    }

    func row(_ number: Int, from origin: Int) -> Int? {
        switch self {
        case .rows:
            return number

        case let .documents(held):
            guard let view = held[origin], view.indices.contains(number) else { return nil }

            return view[number]
        }
    }
}
