//
//  DispatchOperation.swift
//  Warp
//
//  Created by JSilver on 9/6/26.
//

import Foundation

// A call through a contract, as the run makes it: the value it is about,
// what else the call was written with, and one lowered call for every type
// that answers the procedure.
//
// Apart from `CallOperation` because the two are different facts. A call names
// the row the link settled; this names a contract's procedure and leaves which
// rows answer it to the link, because which types answer a contract is a fact
// of the graph rather than of the document holding the call. A document's own
// text cannot say it: a type declared in a document this one never names can
// answer a contract this one calls through.
//
// So `calls` is empty in what compiling a document answers, and the link fills
// it from the types it found. The run still picks and nothing else: every call
// in there is placed against its own row, arguments in that row's slot order.
struct DispatchOperation: Sendable {
    // MARK: - Property
    let contract: Name
    let procedure: Name

    // The first argument, read once. Its name picks the call, and the call is
    // made with what was read rather than with a second reading of the same
    // operand.
    let first: Operation

    // The arguments after the first, by position. Lowered once: where an
    // argument lands is the answering row's to say, and the rows are many.
    let arguments: [Argument]

    // By the name of the type that answers, each with nothing at its first
    // position. Empty until the link fills it.
    let calls: [Name: CallOperation]

    // MARK: - Initializer
    init(
        contract: Name,
        procedure: Name,
        first: Operation,
        arguments: [Argument],
        calls: [Name: CallOperation] = [:]
    ) {
        self.contract = contract
        self.procedure = procedure
        self.first = first
        self.arguments = arguments
        self.calls = calls
    }

    // MARK: - Public
    // MARK: - Private
}
