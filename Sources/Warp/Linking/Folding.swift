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
    let table: [Linked]
    let rows: [Name: Int]
    let words: [Name: Int]
    let shapes: ShapeTable

    // MARK: - Initializer
    init(
        constants: [Name: Value],
        origin: Int,
        table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        shapes: ShapeTable
    ) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.table = table
        self.rows = rows
        self.words = words
        self.shapes = shapes
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
                        in: shapes
                    )
                )
            }
        }

        self.init(constants: bindings, origin: 0, table: table, rows: rows, words: words, shapes: shapes)
    }

    // MARK: - Public
    // What a closure made here is called. It was written in no declaration:
    // the link made it while settling one, and that is what a trace through
    // it says.
    static let label: Name = "folding"

    // Whether a name is bound here.
    func holds(_ name: Name) -> Bool {
        names.contains(name)
    }

    // What a path reads here.
    func read(_ path: [PathSegment], at place: Place) throws -> Value {
        try read(.reference(path), at: place)
    }

    // What an expression reads here. A closure it holds is carried in the
    // code, so the table is read and never grown.
    func read(_ expression: Expression, at place: Place = .given(Self.label.spelling)) throws -> Value {
        let lowering = Lowering(table: table, rows: rows, words: words, variables: [:], shapes: shapes)
        let (code, frame) = try lowering.lower(expression, reading: names, origin: origin, label: Self.label, at: place)
        var activation = Activation(frame)

        for (slot, cell) in cells.enumerated() {
            activation.cells[slot] = cell
        }

        return try Executor(observer: nil, environment: nil, linked: table, shapes: shapes).read(code, in: activation)
    }

    // MARK: - Private
}
