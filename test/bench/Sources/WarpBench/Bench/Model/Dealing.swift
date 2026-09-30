//
//  Dealing.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation

// A count of procedures dealt into a count of documents: which run of them each
// document holds.
//
// In runs rather than one at a time round the documents, so a document holding
// several holds ones that stand next to each other. What a world makes of that
// is the world's own business.
struct Dealing {
    private enum Refusal: Error {
        // A world of no procedures leaves every document declaring none, and a
        // document declares at least one.
        case procedureless

        // Fewer documents than one, or more documents than there are procedures to
        // put in them: either way a document is left with nothing.
        case undealable
    }

    // MARK: - Property
    let procedures: Int
    let documents: Int

    // MARK: - Initializer
    init(of procedures: Int, across documents: Int) throws {
        guard procedures > 0 else { throw Refusal.procedureless }
        guard 1 ... procedures ~= documents else { throw Refusal.undealable }

        self.procedures = procedures
        self.documents = documents
    }

    // MARK: - Public
    // The run of procedures one document holds.
    func held(by document: Int) -> Range<Int> {
        (document * procedures / documents) ..< ((document + 1) * procedures / documents)
    }

    // MARK: - Private
}
