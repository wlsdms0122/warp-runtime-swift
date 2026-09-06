//
//  DispatchOperation.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// A call through a contract, as the run makes it: the value the word is sent
// to, and one lowered call for every type that answers the word.
//
// Apart from `CallOperation` because the two are different facts. A call names
// the row the link settled; this names the rows the link found and leaves the
// choosing to the one thing the link could not see, which is the name the
// value wears. The link still did the work: every call in here is lowered
// against its own row, arguments in that row's slot order, so the run picks
// one and makes it the way it makes any other.
struct DispatchOperation: Sendable {
    // MARK: - Property
    let contract: Name
    let word: Name

    // Read once. Its name picks the call, and the call is made with what was
    // read rather than with a second reading of the same operand.
    let receiver: Operation

    // By the name of the type that answers, each with no receiver of its own.
    let calls: [Name: CallOperation]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
