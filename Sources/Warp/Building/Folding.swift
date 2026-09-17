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
    let loweredTypes: LoweredTypeTable

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
        loweredTypes: LoweredTypeTable
    ) {
        let names = constants.keys.sorted()

        self.names = names
        self.cells = names.map { name in .value(constants[name] ?? .null) }
        self.origin = origin
        self.loweredTypes = loweredTypes
        self.answered = answered
    }

    // Against a link already made: every declaration it holds answers here the
    // way it answers a body, whether the host wrote it or a document did. The
    // numbers a body carries are rows after a link, which is the same reading
    // a run makes of them.
    init(bindings: [Name: Value], in image: Image) {
        self.init(
            constants: bindings,
            origin: 0,
            in: .unanswerable(image.linked, rows: image.rows),
            loweredTypes: image.loweredTypes
        )
    }

    // Against native procedures alone: every declaration of the modules by its
    // spelling, a written body standing as the refusal it earns before it is
    // lowered. A native's constness is its own; a written body is never run
    // here, so its constness is not asked. A procedure a caller brought stands
    // as its own refusal, since a constant settles from the standard vocabulary
    // and from bodies in the link.
    init(bindings: [Name: Value], natives modules: [Module]) {
        // The natives declare the types their own signatures name, so the
        // table is theirs.
        let loweredTypes = TypeTable(
            types: modules.reduce(into: [:]) { table, module in table.merge(module.types) { first, _ in first } },
            constraints: modules.reduce(into: [:]) { table, module in table.merge(module.constraints) { first, _ in first } }
        ).loweredTypes
        var table: [Linked] = []
        var rows: [Name: Int] = [:]

        for (origin, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                rows[name] = table.count
                table.append(
                    Linked.standing(
                        label: name,
                        origin: origin,
                        procedure: procedure,
                        const: procedure.implementation.isNativelyConst == true,
                        isolated: false,
                        failing: procedure.implementation.nativelyFailing ?? .unstated,
                        builtin: module.builtin,
                        // A constant settles before the link's table exists, so
                        // a procedure that sends has no row to send to. It refuses
                        // when it tries, the way one with a written body does.
                        sends: [],
                        in: loweredTypes
                    ).folding
                )
            }
        }

        self.init(
            constants: bindings,
            origin: 0,
            in: .unanswerable(table, rows: rows),
            loweredTypes: loweredTypes
        )
    }

    // MARK: - Public
    // What a fold with no document behind it writes under. Its table numbers
    // its own rows, so nothing looks the name up.
    static let assembled: Name = "folding"

    // What an expression a document's declaration wrote reads here, lowered
    // into the document's own rows. A closure it holds is a closure literal of
    // its document, so it takes a row of that document's block and a number of
    // its numbering, the same as one written in a body.
    func read(
        _ expression: Expression,
        as label: Name,
        writing lowering: inout Lowering,
        at place: Place
    ) async throws -> Value {
        let (code, frame) = try lowering.lower(
            expression,
            reading: names,
            origin: origin,
            label: label,
            at: place
        )

        // The table as a fold reads it. Lowering holds the rows a run reads,
        // and the two differ in one place: a procedure a caller brought
        // answers a run and stands as its refusal here.
        return try await read(
            code,
            in: frame,
            of: answered.holding(lowering.table.map(\.folding), closures: lowering.closureRows),
            at: place
        )
    }

    // Whether a name is bound here.
    func holds(_ name: Name) -> Bool {
        names.contains(name)
    }

    // What a path reads here.
    func read(_ path: [PathSegment], at place: Place) async throws -> Value {
        try await read(.reference(path), at: place)
    }

    // What an expression reads here, lowered into a table of its own. For what
    // is folded where no declaration is being read: a path a body writes, and a
    // condition a caller hands over. A closure written in one is numbered by
    // nothing this document holds and is refused where it is lowered.
    func read(_ expression: Expression, at place: Place = .given(Folding.assembled.spelling)) async throws -> Value {
        guard let numbering = answered.numbering(of: origin) else {
            throw BuildError.unjudged("an expression in a document that numbered nothing", at: place)
        }

        var lowering = Lowering(
            table: answered.table,
            rows: answered.rows,
            numbering: [origin: numbering],
            loweredTypes: loweredTypes
        )
        let (code, frame) = try lowering.lower(
            expression,
            reading: names,
            origin: origin,
            label: Folding.assembled,
            at: place
        )

        // Against the table lowering just grew: what it wrote takes rows of
        // that table and nothing else answers them.
        return try await read(
            code,
            in: frame,
            of: answered.holding(lowering.table, closures: lowering.closureRows),
            at: place
        )
    }

    // MARK: - Private
    private func read(_ code: Operation, in frame: Frame, of answered: Answered, at place: Place) async throws -> Value {
        var activation = Activation(frame, of: origin)

        for (slot, cell) in cells.enumerated() {
            activation.cells[slot] = cell
        }

        let executor = Executor(
            observer: nil,
            environment: nil,
            linked: answered.table,
            resolving: answered.resolving,
            loweredTypes: loweredTypes
        )
        let value = try await executor.read(code, in: activation)

        // What leaves a fold is a value. A closure that took a hold took a
        // box of the run that folded it, and a link holds no run's boxes.
        var sharing = false
        value.closures { closure in sharing = sharing || closure.tookAHold }

        guard !sharing else {
            throw BuildError(
                "settles to a closure holding a variable of the run that folded it,"
                    + " and a link holds values",
                at: place
            )
        }

        return value
    }
}
