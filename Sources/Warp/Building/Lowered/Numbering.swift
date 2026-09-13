//
//  Numbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where a lowered body's numbers come from, and what each one stands for.
//
// A document numbers from itself: the names it looks for outside itself first,
// its own declarations after. A call in its body is one of those numbers and
// nothing else, so what the document lowers to says nothing about the graph it
// was linked into, and the same text numbers the same way in every link.
//
// What runs while a link is still being made is numbered by that link's table
// instead. Folding a constant lowers an expression and runs it there and then,
// and code that never leaves has no link afterwards to answer it.
struct Numbering: Sendable {
    // One name a document looks for, by the declared spelling it writes. A
    // document's own declaration is looked for the same way an imported one
    // is: the number is the document's, and which row it is stays the link's.
    enum Reference: Sendable {
        case sent(Name)

        // A closure literal the document wrote, by which one it is. Lifting one
        // out leaves a procedure no declared spelling reaches, so the link
        // answers it by position rather than by spelling.
        case closure(Int)

        // MARK: - Internal
        var written: Value {
            switch self {
            case let .sent(name):
                return .array([.int(0), .string(name.spelling)])

            case let .closure(number):
                return .array([.int(1), .int(number)])
            }
        }

        init(written value: Value) throws {
            var fields = try Fields(value, of: "numbering reference")

            switch try fields.tag() {
            case 0:
                self = .sent(Name(normal: try fields.text()))

            case 1:
                self = .closure(try fields.count())

            default:
                throw ArtifactRefused("'numbering reference' names nothing this reads")
            }

            try fields.end()
        }
    }

    // What a number turned out to be, with the reason where it is not a row:
    // a name the link does not have, or a number the document never gave.
    enum Answer: Sendable {
        case row(Int)
        case unfound(Reference)
        case unnumbered
    }

    // MARK: - Property
    private let space: Space
    private let called: [Name: Int]

    // Where each declaration's closures start, by the declaration. A closure
    // is the nth one its declaration wrote, and the declarations run in name
    // order, so which number a closure takes is the document's text and not
    // the order the link happened to lower in.
    private let closing: [Name: Int]

    // The first number the closures take. What a body carries is a number of
    // this document; which of its closures that is, is the number less this.
    private let opening: Int

    // MARK: - Initializer
    // A document's own. The imports, its own declarations, and the closures
    // those declarations wrote, each in name order: the numbering is the
    // document's fact and a set has no order to lend it.
    //
    // `closures` says how many each of the document's names wrote, which is
    // read off the document rather than counted while lowering. Lowering runs the procedures
    // before the rest, and which declarations are procedures is a fact of the graph,
    // so a number counted in that order would move when an unrelated module
    // joins the link.
    init(imports: Set<Name>, declared: [Name], closures: [Name: Int] = [:]) {
        let sent = imports.sorted()
        let opening = sent.count + declared.count

        // In name order, over whatever wrote one. A procedure, a constant and
        // a variable are all names the document declared, and a name holds one
        // thing, so the three are one order.
        var starting: [Name: Int] = [:]
        var written = 0

        for name in closures.keys.sorted() {
            guard let count = closures[name], count > 0 else { continue }

            starting[name] = opening + written
            written += count
        }

        space = .document(
            sent.map(Reference.sent)
                + declared.map(Reference.sent)
                + (0..<written).map(Reference.closure)
        )
        called = Self.placed(sent, from: 0)
            .merging(Self.placed(declared, from: sent.count)) { _, own in own }
        closing = starting
        self.opening = opening
    }

    // A table's own. The number a body carries here is the row.
    init(rows: [Name: Int]) {
        space = .table
        called = rows
        closing = [:]
        opening = 0
    }


    // MARK: - Internal
    // What this counts from, said as a value, so an artifact carries the
    // numbering its bodies were lowered against. Written here because what it
    // holds is its own: the spellings and the closure count it was built from
    // are not on the artifact anywhere else.
    var written: Value {
        let space: Value = switch self.space {
        case let .document(references):
            .array([.int(0), .array(references.map(\.written))])

        case .table:
            .array([.int(1)])
        }

        return .array([space, Self.written(called), Self.written(closing), .int(opening)])
    }

    init(written value: Value) throws {
        var fields = try Fields(value, of: "numbering")
        var space = try Fields(try fields.next(), of: "numbering space")

        switch try space.tag() {
        case 0:
            self.space = .document(try space.list(Reference.init(written:)))

        case 1:
            self.space = .table

        default:
            throw ArtifactRefused("'numbering' is counted from nothing this reads")
        }

        try space.end()

        called = try Self.read(try fields.next(), of: "numbering names")
        closing = try Self.read(try fields.next(), of: "numbering closures")
        opening = try fields.count()

        try fields.end()
    }

    private static func written(_ places: [Name: Int]) -> Value {
        .array(places.keys.sorted().map { name in
            .array([.string(name.spelling), .int(places[name]!)])
        })
    }

    private static func read(_ value: Value, of part: String) throws -> [Name: Int] {
        guard case let .array(written) = value else {
            throw ArtifactRefused("'\(part)' is not written as a list")
        }

        return try written.reduce(into: [Name: Int]()) { places, entry in
            var place = try Fields(entry, of: part)
            let name = Name(normal: try place.text())

            guard places.updateValue(try place.count(), forKey: name) == nil else {
                throw ArtifactRefused("'\(part)' writes '\(name)' twice")
            }

            try place.end()
        }
    }

    // MARK: - Public
    // Whether the numbers here are already rows. A table's own numbering
    // answers every number with itself, so what it lowers stands where it was
    // put rather than where a document said.
    var numbersAreRows: Bool {
        guard case .table = space else { return false }

        return true
    }

    // How many closures this document numbers. A link answers them by the rows
    // they took, and a list shorter than this is a document whose bodies are
    // not all lowered yet.
    var closureCount: Int {
        guard case let .document(references) = space else { return 0 }

        return references.count - opening
    }

    // Which row of a link the number stands for, read from the tables that
    // link built.
    func row(_ number: Int, rows: [Name: Int], closures: [Int]) -> Answer {
        guard case let .document(references) = space else { return .row(number) }
        guard references.indices.contains(number) else { return .unnumbered }

        let reference = references[number]

        switch reference {
        case let .sent(declared):
            return rows[declared].map(Answer.row) ?? .unfound(reference)

        case let .closure(written):
            guard closures.indices.contains(written) else { return .unfound(reference) }

            return .row(closures[written])
        }
    }

    // Which row of a link each number this document gave stands for, in
    // number order. A numbering that took the link's rows gave no numbers of
    // its own, so it answers with nothing.
    //
    // Read once per number rather than once per body standing on one: a
    // document gives a number to a name, and how many bodies write that name
    // is not part of the question.
    //
    // The names only. The closures run after them and a link answers those by
    // the rows they took, which is a list it already holds.
    func answers(rows: [Name: Int]) -> [Answer] {
        guard case .document = space else { return [] }

        return (0..<opening).map { number in
            row(number, rows: rows, closures: [])
        }
    }

    // Where a call to this spelling stands: among the document's own
    // declarations where it declared one, among what it looks for otherwise.
    func call(_ selector: Name) -> Int? {
        called[selector]
    }

    // Where the nth closure a declaration wrote stands: the number its body
    // carries, and which of the document's closures that is. Nil where the
    // document was never read for that declaration's closures, which is a link
    // lowering a body it never scanned.
    func closure(_ written: Int, of declared: Name) -> (number: Int, written: Int)? {
        guard let start = closing[declared] else { return nil }

        return (number: start + written, written: start + written - opening)
    }

    // MARK: - Private
    private init(
        space: Space,
        called: [Name: Int],
        closing: [Name: Int],
        opening: Int
    ) {
        self.space = space
        self.called = called
        self.closing = closing
        self.opening = opening
    }

    // What a number is counted from. The document's list is the whole of the
    // difference: the tables below answer a spelling either way.
    private enum Space: Sendable {
        case document([Reference])
        case table
    }

    private static func placed(_ names: [Name], from start: Int) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = start + entry.offset
        }
    }
}
