//
//  Folding+Evaluation.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

extension Folding {
    // A condition read here, as the bool it answers.
    func evaluate(_ condition: Warp.Expression) async throws -> Bool {
        guard case let .bool(answer) = try await read(condition, at: .given("test")) else {
            throw ReadingError("a condition must answer bool")
        }

        return answer
    }
}
