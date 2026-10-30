//
//  DispatchOperation.swift
//  Warp
//
//  Created by JSilver on 9/6/26.
//

import Foundation

// A call through a contract, as the run makes it: the type each of its
// positions reads as, what the call was written with, and one lowered call
// for every type that conforms to the contract.
//
// A call names the row the link picked; this names a contract's procedure,
// and which types conform to its contract is a fact of the link: a type
// declared in a document this one never names can conform to a contract this
// one calls through. So `calls` is empty in what compiling a document returns,
// and the link fills it from the types it found. The run picks by the name of
// the type that fills `Self` and does nothing else: every call in there is
// placed against its own row, arguments in that row's slot order.
struct DispatchOperation: Sendable {
    // MARK: - Property
    let contract: Name
    let procedure: Name

    // What each position of the contract's procedure reads as, in position
    // order, the contract's type parameters filled as the build judged the
    // call: a type, which may name a type parameter of the body the call
    // stands in, read there by what the run holds for it. The first is what
    // fills `Self`, and its name picks the call; the row picked fills its own
    // type parameters from all of them.
    let types: [LoweredType]

    // The first argument and the arguments after it, by position. Lowered
    // once: where an argument lands, and whether a place handed is taken in
    // place, is for the row satisfying it to say, and the rows are many.
    let first: Argument
    let arguments: [Argument]

    // By the name of the type that conforms, each placed against its row.
    // Empty until the link fills it.
    let calls: [Name: PlacedCall]

    // MARK: - Initializer
    init(
        contract: Name,
        procedure: Name,
        types: [LoweredType],
        first: Argument,
        arguments: [Argument],
        calls: [Name: PlacedCall] = [:]
    ) {
        self.contract = contract
        self.procedure = procedure
        self.types = types
        self.first = first
        self.arguments = arguments
        self.calls = calls
    }

    // MARK: - Public
    // The call this makes of a row satisfying it, placed against that row's
    // slots. How many arguments it stands is held where its number becomes a
    // row, as a named call's is. What fills the row's type parameters the run
    // reads off `types`.
    func call(of callee: Linked, at row: Int, in loweredTypes: LoweredTypeTable, at place: Place) throws -> PlacedCall {
        try callee.refuseCall(standing: arguments.count + 1, at: place)

        return try PlacedCall(handing: [first] + arguments, to: callee, row: row, picked: true, in: loweredTypes, at: place)
    }

    // The same call with its types, its first and its arguments rewritten. The calls
    // beside it are the link's to lay out, so they are handed over as they
    // stand and left to the relocation.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> DispatchOperation {
        DispatchOperation(
            contract: contract,
            procedure: procedure,
            types: try types.map(type),
            first: try first.rewritten(operation: operation, type: type),
            arguments: try arguments.map { argument in try argument.rewritten(operation: operation, type: type) },
            calls: calls
        )
    }

    // MARK: - Private
}
