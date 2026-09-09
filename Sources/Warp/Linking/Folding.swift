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
// run reads them, so what the link folds and what a run computes are one
// reading.
struct Folding {
    // MARK: - Property
    let names: [Name]
    let cells: [Cell]
    let origin: Int
    let shapes: ShapeTable

    // The table this folds against, and how the numbers its bodies carry are
    // read. An expression folded beside them is lowered in the same numbering,
    // so one run stands in one numbering.
    private let answered: Answered

    // MARK: - Initializer
    // The table is one that says how its numbers read, since folding runs what
    // it lowers and running reads rows.
    init(
        constants: [Name: Value],
        origin: Int,
        in answered: Answered,
        shapes: ShapeTable
    ) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.shapes = shapes
        self.answered = answered
    }

    // Against native words alone: every declaration of the modules by its
    // spelling and by its last segment, a written body standing as the
    // refusal it earns before it is lowered. What a constant settles from. A
    // native's purity is its own; a written body is never run here, so its
    // purity is not asked.
    init(bindings: [Name: Value], natives modules: [Module]) {
        // The natives declare the shapes their own signatures name, so the
        // table is theirs.
        let shapes = TypeTable(
            types: modules.reduce(into: [:]) { table, module in table.merge(module.types) { first, _ in first } },
            constraints: modules.reduce(into: [:]) { table, module in table.merge(module.constraints) { first, _ in first } }
        ).shapes
        var table: [Linked] = []
        var rows: [Name: Int] = [:]
        var words: [Name: Int] = [:]

        for (origin, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                rows[name] = table.count
                words[name.unqualified] = table.count
                table.append(
                    Linked.standing(
                        label: name,
                        origin: origin,
                        procedure: procedure,
                        pure: procedure.implementation.isNativelyPure == true,
                        isolated: false,
                        failing: procedure.implementation.nativelyFailing ?? .unstated,
                        // A constant settles before the link's table exists, so
                        // a word that sends has no row to send to. It refuses
                        // when it tries, the way one with a written body does.
                        sends: [],
                        in: shapes
                    )
                )
            }
        }

        self.init(
            constants: bindings,
            origin: 0,
            in: .unanswerable(table, rows: rows, words: words),
            shapes: shapes
        )
    }

    // MARK: - Public
    // What a closure made here is called. It was written in no declaration.
    static let label: Name = "folding"

    // Whether a name is bound here.
    func holds(_ name: Name) -> Bool {
        names.contains(name)
    }

    // What a path reads here.
    func read(_ path: [PathSegment], at place: Place) throws -> Value {
        try read(.reference(path), at: place)
    }

    // What an expression reads here. A closure it holds takes a row of its
    // own, so the table this runs against is the one lowering just grew.
    func read(_ expression: Expression, at place: Place = .given(Self.label.spelling)) throws -> Value {
        // Folding runs what it lowers beside bodies the table already holds,
        // so it lowers in the numbering those bodies stand in. A number the
        // expression carries and a number a body it calls carries are then
        // read the same way.
        guard let numbering = answered.numbering(of: origin) else {
            throw LinkError.unjudged("an expression in a document that numbered nothing", at: place)
        }

        // Room for the closures this expression writes. They stand after the
        // document's own, and the rows they take are handed to the run below
        // the same way.
        let written = expression.buried.count { held in
            guard case .closure = held else { return false }

            return true
        }

        var lowering = Lowering(
            table: answered.table,
            rows: answered.rows,
            words: answered.words,
            numbering: [origin: numbering.folding(written, for: Self.label)],
            variables: [:],
            shapes: shapes
        )
        let (code, frame) = try lowering.lower(expression, reading: names, origin: origin, label: Self.label, at: place)
        var activation = Activation(frame, of: origin)

        for (slot, cell) in cells.enumerated() {
            activation.cells[slot] = cell
        }

        let executor = Executor(
            observer: nil,
            environment: nil,
            linked: lowering.table,
            resolving: answered.resolving.holding(lowering.closureRows[origin] ?? [], of: origin),
            shapes: shapes
        )

        return try executor.read(code, in: activation)
    }

    // MARK: - Private
}
