//
//  Assembled.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// The documents of one link, laid end to end, and the tables that say what
// its rows are. Where a document's rows first stand somewhere.
//
// No body is read: the blocks are copied in, in the order the host handed
// them over, and each name resolves to where its block began.
struct Assembled: Sendable {
    // One row of the link: the judged row, which document it came out of,
    // and which of its writer's closures it is where a closure was lifted
    // into it. One value per row, so the three cannot come apart.
    struct Row: Sendable {
        // MARK: - Property
        let judged: Judged
        let origin: Int
        let closure: (by: Closure.Declaration, nth: Int)?

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let table: [Row]

    // Which document each block came out of, for a refusal that names one.
    let documents: [Place.Document]

    // What a closure each document writes is spelled with.
    let naming: [Closure.Document]

    // Every declared spelling, by row.
    let rows: [Name: Int]

    // Each document's own declarations by row, private ones included, which
    // its own numbers resolve by. And the spellings the private ones wear,
    // which `rows` does not hold and a refusal reads to say why a lookup
    // failed: nothing outside their documents names them.
    let owned: [[Name: Int]]
    let concealed: Set<Name>

    // Which row each document's closures took, in the order that document
    // numbers them. A closure is a row like any other and no declared
    // spelling reaches it, so it stands here rather than in `rows`.
    let closures: [[Int]]

    // By document, which is what a body carries and what a row says it
    // came from. Read at every row walked, so read by position.
    let numbering: [Numbering]
    let typeNumbering: [LoweredTypeNumbering]
    let variables: [[(name: Name, value: Value)]]

    // Which row a closure a value holds stands at, by its spelling.
    let spelled: ClosureRowTable

    // MARK: - Initializer
    // Each document is read in place and once. A compiled document is a
    // wide value, and every pass that took one by value paid for the whole
    // of it to read one field.
    init(_ documents: [Compiled]) throws {
        let held = documents.indices.reduce(0) { held, origin in held + documents[origin].table.count }

        var table: [Row] = []
        var rows: [Name: Int] = [:]
        var owned: [[Name: Int]] = []
        var concealed: Set<Name> = []
        var closures = [[Int]](repeating: [], count: documents.count)
        var named: [Place.Document] = []
        var naming: [Closure.Document] = []
        var numbering: [Numbering] = []
        var typeNumbering: [LoweredTypeNumbering] = []
        var variables: [[(name: Name, value: Value)]] = []

        table.reserveCapacity(held)
        rows.reserveCapacity(held)
        named.reserveCapacity(documents.count)
        naming.reserveCapacity(documents.count)
        numbering.reserveCapacity(documents.count)
        typeNumbering.reserveCapacity(documents.count)
        variables.reserveCapacity(documents.count)

        for origin in documents.indices {
            let start = table.count
            let document = documents[origin].document

            let withheld = documents[origin].hidden
            var own: [Name: Int] = [:]

            for (offset, name) in documents[origin].declared.enumerated() {
                own[name] = start + offset

                // A private declaration takes no spelling from the link: its
                // own document reaches it by its own rows, so two documents
                // may each declare one under one spelling.
                guard !withheld.contains(name) else {
                    concealed.insert(name)

                    continue
                }

                // A name two documents declare is a table that cannot say
                // which row that name is, so it is refused where the table is
                // made rather than resolved to whichever was laid down last.
                // Documents compiled together are held to this already;
                // documents compiled apart meet here for the first time.
                if let taken = rows[name] {
                    let first = table[taken].origin

                    throw BuildError.declaredTwice(
                        name,
                        by: named[first].spelled(at: first),
                        and: document.spelled(at: origin),
                        at: .procedure(name.spelling, in: document)
                    )
                }

                rows[name] = start + offset
            }

            owned.append(own)
            closures[origin] = documents[origin].lifted.map { row in start + row }

            for index in documents[origin].table.indices {
                table.append(
                    Row(judged: documents[origin].table[index], origin: origin, closure: documents[origin].closure(ofRow: index))
                )
            }

            named.append(document)
            naming.append(documents[origin].naming)
            numbering.append(documents[origin].numbering)
            typeNumbering.append(documents[origin].typeNumbering)
            variables.append(documents[origin].variables)
        }

        self.table = table
        self.documents = named
        self.naming = naming
        self.spelled = ClosureRowTable(naming: naming, numbering: numbering, closures: closures, documents: named)
        self.rows = rows
        self.owned = owned
        self.concealed = concealed
        self.closures = closures
        self.numbering = numbering
        self.typeNumbering = typeNumbering
        self.variables = variables
    }

    // MARK: - Public
    // MARK: - Private
}
