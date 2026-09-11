//
//  Dealing.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation

// A count of words dealt into a count of documents: which run of them each
// document holds.
//
// In runs rather than one at a time round the documents, so a document holding
// several holds ones that stand next to each other. What a world makes of that
// is the world's own business.
struct Dealing {
    // MARK: - Property
    let words: Int
    let documents: Int

    // MARK: - Initializer
    init(of words: Int, across documents: Int) throws {
        guard words > 0 else { throw Refusal.wordless }
        guard 1 ... words ~= documents else { throw Refusal.undealable }

        self.words = words
        self.documents = documents
    }

    // MARK: - Public
    // The run of words one document holds.
    func held(by document: Int) -> Range<Int> {
        (document * words / documents) ..< ((document + 1) * words / documents)
    }

    // MARK: - Private
    private enum Refusal: Error {
        // A world of no words holds nothing to start a build from.
        case wordless

        // Fewer documents than one, or more documents than there are words to
        // put in them: either way a document is left with nothing.
        case undealable
    }
}
