//
//  TicketQuery.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

final class TicketQuery: Query, @unchecked Sendable {
    typealias Parameters = NoParameters

    // MARK: - Property
    let isolated = false

    private let lock = NSLock()
    private var issued = 0

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<TicketQuery>) async throws -> Value {
        .int(lock.withLock {
            issued += 1

            return issued
        })
    }

    // MARK: - Private
}
