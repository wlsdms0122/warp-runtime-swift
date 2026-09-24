//
//  AppendingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The elements with one more at the end. Nothing is written in place: this
// answers a new array, which is what a language whose names are fixed by
// default can offer.
struct AppendingQuery: Query {
    typealias Parameters = ArrayAndElement

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Answered in the spelling the collection arrived in, so a compact one
        // stays compact until an element that is not a byte is put among them,
        // which `adding` reads for itself. Only the arriving element decides
        // that, so only it is looked at.
        let collection = question[.array]

        guard collection.elements != nil else { return nil }

        return collection.adding(question[.element], atFront: false)
    }

    // MARK: - Private
}
