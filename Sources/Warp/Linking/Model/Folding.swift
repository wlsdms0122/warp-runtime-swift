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
    init(constants: [String: Value], origin: Int, lowering: Lowering, types: TypeTable) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.table = lowering.table
        self.rows = lowering.rows
        self.words = lowering.words
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
                let implementation: Linked.Implementation

                switch procedure.implementation {
                case .body:
                    implementation = .query(UnsettledWord())

                case let .query(query):
                    implementation = .query(query)

                case let .effect(effect):
                    implementation = .effect(effect)
                }

                rows[name] = table.count
                words[String(name.split(separator: ".").last ?? Substring(name))] = table.count
                table.append(
                    Linked(
                        label: name,
                        origin: origin,
                        signature: procedure.signature,
                        purity: procedure.implementation.isNativelyPure == true ? .pure : .unstated,
                        isolation: .unstated,
                        implementation: implementation
                    )
                )
            }
        }

        self.init(
            constants: bindings,
            origin: 0,
            lowering: Lowering(table: table, rows: rows, words: words, variables: [:]),
            types: types
        )
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

    // What an expression reads here. A closure it holds is lowered into a
    // table this reading keeps to itself.
    func read(_ expression: Expression, at place: Place = .given("folding")) throws -> Value {
        var lowering = Lowering(table: table, rows: rows, words: words, variables: [:])
        let code = try lowering.lower(expression, reading: names, origin: origin, label: "", at: place)

        return try Executor(observer: nil, environment: nil, linked: lowering.table, types: types)
            .read(code, in: Activation(cells: cells, names: names))
    }

    // MARK: - Private
}
