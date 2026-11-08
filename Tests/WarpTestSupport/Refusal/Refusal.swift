//
//  Refusal.swift
//  WarpTestSupport
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
import Warp

// The one refusal a build refused with. Anything else is recorded as an
// issue at the caller: no refusal, another error, or more than one.
@discardableResult
public func expectRefusal<Built>(
    sourceLocation: SourceLocation = #_sourceLocation,
    _ building: () async throws -> Built
) async -> BuildError? {
    let refused = await #expect(throws: BuildRefused.self, sourceLocation: sourceLocation) {
        try await building()
    }

    guard let refused else { return nil }

    #expect(refused.refusals.count == 1, "\(refused)", sourceLocation: sourceLocation)

    return refused.refusals.first
}
