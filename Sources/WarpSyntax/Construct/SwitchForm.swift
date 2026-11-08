//
//  SwitchForm.swift
//  WarpSyntax
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Warp

// A value of an enum taken apart: the arm under its case runs, with the
// fields it binds, and a case no arm names takes `default`. A switch holds at
// least one arm, since one with none would say what its `default` says alone.
struct SwitchForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case of
        case cases
        case `default`
    }

    // MARK: - Property
    static let key: Name = "switch"

    private let switched: Warp.Expression
    private let cases: [Name: Arm]
    private let otherwise: Body?

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "switch")

        self.switched = try decoder.descending(to: CodingKeys.of).read(ExpressionReader.self).expression

        let arms = try decoder.descending(to: CodingKeys.cases)

        guard case .dictionary = try ValueReader(from: arms).value else {
            throw ReadingError("`cases` is a dictionary of each case to the arm that runs for it", at: try arms.steps)
        }

        self.cases = try arms.read([Name: ArmReader].self).mapValues(\.arm)

        guard !cases.isEmpty else {
            throw ReadingError(Warp.Expression.switchHoldingNoArm, at: try arms.steps)
        }

        self.otherwise = try decoder.descendingIfPresent(to: CodingKeys.default)?.read(BodyReader.self).body
    }

    // MARK: - Public
    var expression: Warp.Expression {
        .switch(switched, cases: cases, default: otherwise)
    }

    // MARK: - Private
}
