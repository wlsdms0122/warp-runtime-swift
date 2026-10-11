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
// A call names the row the link settled; this names a contract's procedure,
// and which types answer it is a fact of the link: a type declared in a
// document this one never names can answer a contract this one calls through.
// So `calls` is empty in what compiling a document answers, and the link
// fills it from the types it found. The run picks and does nothing else: every call
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
    // The same call with its first and its arguments rewritten. The calls
    // beside it are the link's to lay out, so they are handed over as they
    // stand for the relocation to answer.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> DispatchOperation {
        DispatchOperation(
            contract: contract,
            procedure: procedure,
            first: try first.rewritten(operation: operation, type: type),
            arguments: try arguments.map { argument in try argument.rewritten(operation: operation, type: type) },
            calls: calls
        )
    }

    // MARK: - Private
}
