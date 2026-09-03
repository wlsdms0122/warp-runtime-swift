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
    let names: [String]
    let cells: [Cell]
    let origin: Int
    let table: [Linked]
    let rows: [String: Int]
    let words: [String: Int]
    let types: TypeTable

    // MARK: - Initializer
    init(
        constants: [String: Value],
        origin: Int,
        table: [Linked],
        rows: [String: Int],
        words: [String: Int],
        types: TypeTable
    ) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.table = table
        self.rows = rows
        self.words = words
        self.types = types
    }

    // Against native words alone: every declaration of the modules by its
    // spelling and by its last segment, a written body standing as the
    // refusal it earns before it is lowered. What a constant settles from.
    init(bindings: [String: Value], natives modules: [Module], types: TypeTable = TypeTable()) {
        var table: [Linked] = []
        var rows: [String: Int] = [:]
        var words: [String: Int] = [:]

        for (origin, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                rows[name] = table.count
                words[String(name.split(separator: ".").last ?? Substring(name))] = table.count
                table.append(
                    Linked.standing(
                        label: name,
                        origin: origin,
                        procedure: procedure,
                        pure: procedure.implementation.isNativelyPure == true,
                        isolated: false
                    )
                )
            }
        }

        self.init(constants: bindings, origin: 0, table: table, rows: rows, words: words, types: types)
    }

    // MARK: - Public
    // Whether a name is bound here.
    func holds(_ name: String) -> Bool {
        names.contains(name)
    }

    // What a path reads here.
    func read(_ path: [PathSegment], at place: Place) throws -> Value {
        try read(.reference(path), at: place)
    }

    // What an expression reads here. A closure it holds is carried in the
    // code, so the table is read and never grown.
    func read(_ expression: Expression, at place: Place = .given("folding")) throws -> Value {
        let lowering = Lowering(table: table, rows: rows, words: words, variables: [:])
        let code = try lowering.lower(expression, reading: names, origin: origin, label: "", at: place)

        return try Executor(observer: nil, environment: nil, linked: lowering.table, types: types)
            .read(code, in: Activation(cells: cells, layout: Layout(size: names.count, parameters: [], variables: [], names: names)))
    }

    // MARK: - Private
}
