//
//  LowercasedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The text in lower case, by Unicode's full default case mapping: each code
// point's own mapping, except a capital sigma that ends a word, which lowers
// to the final sigma (the Final_Sigma condition).
struct LowercasedQuery: Query {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("Standard.Text.lowercased asks a String")
        }

        return .string(lowercased(text))
    }

    // MARK: - Private
    private func lowercased(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var lowered = ""

        for (position, scalar) in scalars.enumerated() {
            if scalar == "\u{03A3}", endsWord(scalars, at: position) {
                lowered.unicodeScalars.append("\u{03C2}")
            } else {
                lowered += scalar.properties.lowercaseMapping
            }
        }

        return lowered
    }

    // A cased letter before it and none after, looking past the case-ignorable
    // code points on either side.
    private func endsWord(_ scalars: [Unicode.Scalar], at position: Int) -> Bool {
        let before = scalars[..<position].last { scalar in
            !scalar.properties.isCaseIgnorable
        }
        let after = scalars[(position + 1)...].first { scalar in
            !scalar.properties.isCaseIgnorable
        }

        return before?.properties.isCased == true && after?.properties.isCased != true
    }
}
