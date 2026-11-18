//
//  CodeTable.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// The lowered table a run reads, compiled: a routine per row, and what the
// numbers in those bodies stand for. An image's table compiles every body
// once, as it is made, and every run of the image reads it. A fold's
// compiles a body the first time a call reaches it, since a fold reaches
// few of the rows it is handed.
final class CodeTable: @unchecked Sendable {
    // MARK: - Property
    // The linked table the bodies run against.
    let linked: [Linked]

    // What the numbers in those bodies stand for.
    let resolving: Resolving

    // What a closure the run makes is spelled with, by the origin its row
    // says.
    let naming: [Closure.Document]

    // The types the link declared, by row. Every door and every cast reads
    // it.
    let loweredTypes: LoweredTypeTable

    // The rows satisfying each contract's procedure, by the procedure's
    // spelling and the conforming type, for a call through a contract the
    // link has not laid out yet: what a build folding before the link knows
    // from the claims standing so far. Empty for an image, whose calls the
    // link laid out.
    let witnesses: [Name: [Name: Int]]

    // What each contract's procedure declares, by the spelling a call
    // through the contract writes: what the build judged such a call
    // against, `Self` standing.
    let contractProcedures: [Name: LoweredContractProcedure]

    // By row, and by identity for a row a closure value holds.
    private var routines: [Routine?]
    private var held: [ObjectIdentifier: Routine]

    // By row, a routine for each set of types a call filled the row's type
    // parameters with, its body compiled for them. A row stops taking more
    // at `specializationsPerRow`, so a body that calls itself with types
    // growing each time reaches the row's own routine.
    private var specialized: [Int: [[Name: LoweredType]: Routine]]
    private static let specializationsPerRow = 32

    // An image's table is sealed once it is made: a body compiled after
    // that, one a closure from another table reached, calls the rows'
    // own routines, since nothing writes this table any more.
    private var sealed: Bool

    // Nil for an image's table, which nothing writes once it is made.
    private let lock: NSLock?

    // MARK: - Initializer
    // An image's table, every body compiled now. A row's numbers are rows of
    // this table, since the link relocated them.
    init(
        compiling linked: [Linked],
        naming: [Closure.Document],
        loweredTypes: LoweredTypeTable,
        contractProcedures: [Name: LoweredContractProcedure]
    ) {
        self.linked = linked
        self.resolving = .rows
        self.naming = naming
        self.loweredTypes = loweredTypes
        self.witnesses = [:]
        self.contractProcedures = contractProcedures
        self.routines = []
        self.held = [:]
        self.specialized = [:]
        self.sealed = false
        self.lock = nil

        let made = linked.map { row in Routine(row, in: self, lazily: false) }

        routines = made
        held = Dictionary(
            made.map { routine in (ObjectIdentifier(routine.linked), routine) },
            uniquingKeysWith: { first, _ in first }
        )

        for routine in made {
            routine.compile()
        }

        sealed = true
    }

    // A fold's table, each body compiled when a call first reaches it.
    init(
        linked: [Linked],
        resolving: Resolving,
        naming: [Closure.Document],
        loweredTypes: LoweredTypeTable,
        witnesses: [Name: [Name: Int]],
        contractProcedures: [Name: LoweredContractProcedure]
    ) {
        self.linked = linked
        self.resolving = resolving
        self.naming = naming
        self.loweredTypes = loweredTypes
        self.witnesses = witnesses
        self.contractProcedures = contractProcedures
        self.routines = Array(repeating: nil, count: linked.count)
        self.held = [:]
        self.specialized = [:]
        self.sealed = false
        self.lock = NSLock()
    }

    // MARK: - Public
    // The routine of a row of this table.
    func routine(row: Int) -> Routine {
        guard let lock else { return routines[row]! }

        return lock.withLock {
            if let routine = routines[row] { return routine }

            let made = Routine(linked[row], in: self, lazily: true)

            routines[row] = made

            return made
        }
    }

    // The routine of a row a call fills the type parameters of with `types`,
    // its body compiled for them. An image's table compiles it as the call
    // is compiled, a fold's when a call first reaches it.
    func routine(row: Int, filled types: [Name: LoweredType]) -> Routine {
        guard !types.isEmpty else { return routine(row: row) }

        guard let lock else {
            guard !sealed else { return routine(row: row) }

            if let routine = specialized[row]?[types] { return routine }

            guard specialized[row, default: [:]].count < Self.specializationsPerRow else { return routine(row: row) }

            let made = Routine(linked[row], in: self, filled: types, lazily: false)

            specialized[row, default: [:]][types] = made
            made.compile()

            return made
        }

        let found: Routine? = lock.withLock {
            if let routine = specialized[row]?[types] { return routine }

            guard specialized[row, default: [:]].count < Self.specializationsPerRow else { return nil }

            let made = Routine(linked[row], in: self, filled: types, lazily: true)

            specialized[row, default: [:]][types] = made

            return made
        }

        return found ?? routine(row: row)
    }

    // The routine of the row a closure value holds. A row of an image's
    // table is the one compiled with it; one from anywhere else is compiled
    // where a call reaches it.
    func routine(of row: Linked) -> Routine {
        let identity = ObjectIdentifier(row)

        guard let lock else {
            return held[identity] ?? Routine(row, in: self, lazily: true)
        }

        return lock.withLock {
            if let routine = held[identity] { return routine }

            let made = Routine(row, in: self, lazily: true)

            held[identity] = made

            return made
        }
    }

    // A row's body compiled against this table.
    func compile(
        _ body: LoweredBody,
        in frame: Frame,
        of row: Linked,
        filled types: [Name: LoweredType]? = nil
    ) -> CompiledBody {
        CodeGenerator(table: self, origin: row.origin, names: frame.names, filled: types)
            .body(body, in: frame, standing: row.place)
    }

    // Which row of this table a number written in a body stands for. A number
    // the link found no row for is a body it lowered without judging: nothing
    // a run does can resolve it.
    func row(_ number: Int, from origin: Int) throws -> Int {
        guard let row = resolving.row(number, from: origin) else {
            throw RunRefused("a call standing at \(number) reaches no row of this link")
        }

        return row
    }

    // The row a closure value is a body of, asked before anything reads its
    // rows: it is numbered by the table of the link that made it.
    func row(of closure: Closure) throws -> (row: Linked, types: [Name: LoweredType]) {
        let resolved = try closure.resolved()

        guard resolved.row.readable(in: loweredTypes) else {
            throw RunRefused("this call \(Linked.unreadable)")
        }

        return resolved
    }

    // What fills the type parameters of a row a call through a contract
    // picked: what its parameters read the contract's positions as, the
    // head's parameters among them by what fills `Self`, and each associated
    // type that gives.
    func types(of callee: Linked, reading positions: [LoweredType]) -> [Name: LoweredType] {
        guard !callee.typeParameters.isEmpty else { return [:] }

        return types(of: callee.signature, over: callee.slots, reading: positions)
            .filter { label, _ in callee.typeParameters.contains(label) }
    }

    // What a call returns where the run filled a type parameter of what it
    // called with the type a value read as a contract holds, which the call
    // handed as the contract: held at the call's reading, what is declared
    // read by the types the callee ran with.
    func held(
        _ returned: Value,
        returning declared: LoweredType,
        handed: [Name: LoweredType],
        ran: [Name: LoweredType]
    ) -> Value {
        declared.filling(handed).holding(
            returned,
            readAs: declared,
            filling: { type in type.filling(ran) },
            in: loweredTypes
        )
    }

    // What a call through a contract returns where the value standing first
    // held the type that picked the row: held at the call's reading of what
    // the contract's procedure returns, `Self` read as that type. A return
    // naming no type parameter reads the same whatever filled them.
    func held(
        _ returned: Value,
        through dispatch: DispatchOperation,
        as spelling: Name,
        picked type: LoweredType,
        in activation: Activation
    ) throws -> Value {
        guard let asked = contractProcedures[spelling] else {
            throw RunRefused("'\(spelling)' is called through a contract, and no contract this run reads declares it")
        }

        guard asked.returns.namesParameter else { return returned }

        let handed = dispatch.types.map { type in activation.reading(type) }
        var ran = handed

        ran[0] = type

        return held(
            returned,
            returning: asked.returns,
            handed: types(of: asked.signature, over: asked.slots, reading: handed),
            ran: types(of: asked.signature, over: asked.slots, reading: ran)
        )
    }

    // MARK: - Private
    // What the positions fill the type parameters of a signature with, each
    // associated type among them.
    private func types(
        of signature: Signature,
        over slots: [Slot],
        reading positions: [LoweredType]
    ) -> [Name: LoweredType] {
        var substitution = Substitution(filling: slots.map(\.type), against: positions, in: loweredTypes)
        let associated = signature.associatedTypes

        if !associated.isEmpty {
            substitution.derive(
                associated,
                bounds: signature.bounds,
                said: signature.loweredSameTypes(in: loweredTypes),
                in: loweredTypes
            )
        }

        return substitution.readings.mapValues(\.asHeld)
    }
}
