//
//  Asked.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// What a run hands a query it asks, before it is a question of any one
// procedure's type.
public struct Asked: Sendable {
    // MARK: - Property
    // The arguments a procedure reads, by position in the row a run sent.
    @usableFromInline
    let arguments: ArgumentList

    // The row being asked travels with the run: the sends it declared are its
    // document's numbers, and only a run can say which rows they are.
    let callee: Linked

    let evaluator: Evaluator

    // Where the run was when it asked this procedure, so a refusal in what
    // the procedure sends or calls says where. A trace is built from it only
    // where one is read.
    let location: Location

    // MARK: - Initializer
    init(arguments: ArgumentList, of callee: Linked, evaluator: Evaluator, at location: Location) {
        self.arguments = arguments
        self.callee = callee
        self.evaluator = evaluator
        self.location = location
    }

    // MARK: - Public
    // MARK: - Private
}
