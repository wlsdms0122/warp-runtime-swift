//
//  Folding.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// What an expression folds against before any run: named values as a frame,
// and the table as it stands. A constant's expression, and a body's path
// headed by a constant, are lowered against that frame and read the way a
// run reads them, so what the build folds and what a run computes are one
// reading.
struct Folding {
    // MARK: - Property
    let names: [Name]
    let cells: [Cell]
    let origin: Int
    let loweredTypes: LoweredTypeTable

    // The table this folds against, and how the numbers its bodies carry are
    // read. An expression folded beside them is lowered in the same numbering,
    // so one run stands in one numbering.
    private let resolved: ResolvedTable

    // MARK: - Initializer
    // The table is one that says how its numbers read, since folding runs what
    // it lowers and running reads rows.
    init(
        constants: [Name: Value],
        origin: Int,
        in resolved: ResolvedTable,
        loweredTypes: LoweredTypeTable
    ) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.loweredTypes = loweredTypes
        self.resolved = resolved
    }

    // MARK: - Public
    // What an expression a document's declaration wrote reads here, lowered
    // into the document's own rows. A closure it holds is a closure literal of
    // its document, so it takes a row of that document's block and a number of
    // its numbering, the same as one written in a body.
    func read(
        _ expression: Expression,
        as writer: Closure.Declaration,
        handing inPlace: [Place: [Int]],
        writing lowering: inout Lowering,
        at place: Place
    ) async throws -> Value {
        let (code, frame) = try lowering.lower(
            expression,
            reading: names,
            origin: origin,
            writer: writer,
            inPlace: inPlace,
            at: place
        )

        // The table as a fold reads it. Lowering holds the rows a run reads,
        // and the two differ in one place: a procedure a caller brought
        // answers a run and stands as its refusal here.
        return try await read(
            code,
            in: frame,
            of: resolved.holding(lowering.table.map(\.folding), documents: lowering.documents),
            at: place
        )
    }

    // Whether a name is bound here.
    func holds(_ name: Name) -> Bool {
        names.contains(name)
    }

    // The name a path settles from here, where it settles: headed by a name
    // bound here, and indexed by nothing still a reference. Asked of a path
    // whose index references have been folded, so one still a reference is
    // one only a run settles.
    func settled(_ path: Path) -> Name? {
        guard let head = path.head, holds(head) else { return nil }

        let indexedByTheRun = path.segments.contains { segment in
            if case .indexRef = segment { return true }

            return false
        }

        return indexedByTheRun ? nil : head
    }

    // What a path reads here. A path calls nothing and makes no closure, so
    // it lowers against the types alone and reads the table as it stands.
    func read(_ path: Path, at place: Place) async throws -> Value {
        let (code, frame) = try Lowering(loweredTypes: loweredTypes).lower(
            path,
            reading: names,
            origin: origin,
            at: place
        )

        return try await read(code, in: frame, of: resolved, at: place)
    }

    // MARK: - Private
    private func read(_ code: Operation, in frame: Frame, of resolved: ResolvedTable, at place: Place) async throws -> Value {
        var activation = Activation(frame, of: origin)

        for (slot, cell) in cells.enumerated() {
            activation.cells[slot] = cell
        }

        let evaluator = Evaluator(
            linked: resolved.table,
            resolving: resolved.resolving,
            naming: resolved.naming,
            loweredTypes: loweredTypes
        )
        let value = try await evaluator.read(code, in: activation)

        // What leaves a fold is a value. A closure that took a hold took a
        // box of the run that folded it, and a build holds no run's boxes.
        guard !value.holdsClosure(where: \.tookAHold) else {
            throw BuildError(
                "settles to a closure holding a variable of the run that folded it,"
                    + " and a link holds values",
                at: place
            )
        }

        return value
    }
}
