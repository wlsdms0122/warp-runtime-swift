//
//  FailForm.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

struct FailForm: ConstructForm {
    // MARK: - Property
    static let key: Name = "fail"

    private let recoverable: Bool

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.recoverable = try decoder.singleValueContainer().decode(Bool.self)
    }

    // MARK: - Public
    func expression(boundTo name: Name?) -> Warp.Expression {
        .call(
            Call(selector: "Test.fail", arguments: [.literal(.bool(recoverable))])
        )
    }

    // MARK: - Private
}
