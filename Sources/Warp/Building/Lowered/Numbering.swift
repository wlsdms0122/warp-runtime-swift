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
    }

    // What a number turned out to be, with the reason where it is not a row:
    // a name the link does not have, or a number the document never gave.
    enum Answer: Sendable {
        case row(Int)
        case unfound(Reference)
        case unnumbered
    }

    // What a number is counted from. The document's list is the whole of the
    // difference: the tables below answer a spelling either way.
    //
    // The closures are a count and not a list. A closure's reference is the
    // position it stands at, so a row per closure would hold nothing the
    // count does not already say, and a number read off an object would
    // decide how many of them to stand up.
    private enum Space: Sendable {
        case document(spellings: [Name], closures: Int)
        case table
    }

    // MARK: - Property
    private let space: Space
    private let called: [Name: Int]

    // How many spellings stand in front of the document's own declarations:
    // what it sends.
    private let sent: Int

    // How many closures each declaration wrote, in name order, over the ones
    // that wrote any. The order is the document's own: a closure is the nth
    // one its declaration wrote, and the declarations run in name order, so
    // which number a closure takes is the document's text and not the order
    // the link happened to lower in.
    private let runs: [(name: Name, count: Int)]

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
        guard case let .document(_, closures) = space else { return 0 }

        return closures
    }

    // Every declaration that wrote a closure here.
    var writers: [Name] {
        runs.map(\.name)
    }

    // The first number the closures take. What a body carries is a number of
    // this document; which of its closures that is, is the number less this.
    private var opening: Int {
        guard case let .document(spellings, _) = space else { return 0 }

        return spellings.count
    }

    // MARK: - Initializer
    // A document's own. What it sends, its own declarations, and the closures
    // those declarations wrote, each in name order: the numbering is the
    // document's fact and a set has no order to lend it.
    //
    // `closures` says how many each of the document's names wrote, which is
    // read off the document rather than counted while lowering. Lowering runs the procedures
    // before the rest, and which declarations are procedures is a fact of the graph,
    // so a number counted in that order would move when an unrelated module
    // joins the link.
    init(sends: Set<Name>, declared: [Name], closures: [Name: Int] = [:]) {
        let sent = sends.sorted()
        let counted = closures.filter { _, count in count > 0 }

        self.sent = sent.count
        space = .document(spellings: sent + declared, closures: counted.values.reduce(0, +))
        called = Self.placed(sent, from: 0)
            .merging(Self.placed(declared, from: sent.count)) { _, own in own }
        runs = counted.keys.sorted().map { name in (name: name, count: counted[name] ?? 0) }
    }

    // A table's own. The number a body carries here is the row.
    init(rows: [Name: Int]) {
        space = .table
        called = rows
        sent = 0
        runs = []
    }

    // Read back beside the spellings the document declares, because what a
    // body's number reaches is answered from here rather than from those: the
    // declarations stand at the end of this list, behind what it sends.
    init(written value: Value, declaring declared: [Name]) throws {
        var fields = try Fields(value, of: "numbering")
        let sent = try Fields.ordered(fields.next(), of: "numbering sends") { written in
            try Fields.name(written, of: "numbering sends")
        }
        let counts = try Self.read(try fields.next(), of: "numbering closures")

        try fields.end()

        // A writing counts a name only where that name wrote one, so a count
        // of none is a count no writing lays down, and one writing reads
        // back as one.
        guard counts.values.allSatisfy({ count in count > 0 }) else {
            throw ObjectRefused("a numbering counts no closures for a name it counts")
        }

        // A closure's number stands behind the spellings, so the last number
        // this numbering gives is the spellings and every closure counted
        // together. Counted here, because the door below reaches that number
        // by adding and a sum that leaves an int is not one.
        var standing = sent.count + declared.count

        for count in counts.values {
            let (summed, overflowed) = standing.addingReportingOverflow(count)

            guard !overflowed else {
                throw ObjectRefused("a numbering gives numbers past what an int holds")
            }

            standing = summed
        }

        // Through the door that numbers a document, so that what a reading
        // stands up is a numbering that counting could have reached. A
        // beginning written down is a beginning that can disagree with the one
        // beside it; a count is not.
        self.init(sends: Set(sent), declared: declared, closures: counts)
    }

    // MARK: - Public
    // What this counts from, said as a value, so an object carries the
    // numbering its bodies were lowered against.
    //
    // What is written is what a reading will use and cannot work out. The
    // numbers a name stands at and what counts from what are one arithmetic
    // over the spellings, so writing them down would make a numbering whose
    // parts disagree something an object can hold.
    //
    // How many closures each declaration wrote is neither: folding runs a
    // dependency's body against this, and lowering a closure literal there
    // asks where that declaration's run begins.
    // The spellings this document declares are written once, beside the
    // table, so only what it sends and what it counted stand here.
    func written(dropping declared: Int) -> Value? {
        guard case let .document(spellings, _) = space else { return nil }

        return .array([
            .array(spellings.dropLast(declared).map { name in .string(name.spelling) }),
            .array(runs.map { run in .array([.string(run.name.spelling), .int(run.count)]) })
        ])
    }

    // Whether this document gave a number at all. What it stands for is the
    // link's answer and moves with the link; that it was given is the
    // document's own fact and does not.
    func gave(_ number: Int) -> Bool {
        guard case let .document(spellings, closures) = space else { return true }

        return number >= 0 && number < spellings.count + closures
    }

    // Which of this document's own declarations a number stands at, or
    // nothing where it stands for what the document sends or for a closure.
    func declaring(_ number: Int) -> Int? {
        guard case let .document(spellings, _) = space, number >= sent, number < spellings.count else {
            return nil
        }

        return number - sent
    }

    // Which declaration wrote the closure standing nth among this document's,
    // and which of that declaration's it is: what a closure value is spelled
    // by, wherever the value goes. The closures run in declaration order
    // behind the spellings, so which one owns a number is where that number
    // falls among the runs.
    func writer(of standing: Int) -> (by: Name, nth: Int)? {
        var passed = 0

        for run in runs {
            if standing < passed + run.count { return (by: run.name, nth: standing - passed) }

            passed += run.count
        }

        return nil
    }

    // How many closures a declaration wrote here, or nil where the document
    // was never read for that declaration's closures.
    func count(of declared: Name) -> Int? {
        run(of: declared)?.count
    }

    // Which of this document's closures a number stands for, or nothing where
    // it stands for a spelling instead. A body carries reference numbers, and
    // which closure one of them is, is this document's own arithmetic.
    func lifted(_ number: Int) -> Int? {
        guard case let .document(spellings, closures) = space,
              number >= spellings.count,
              number < spellings.count + closures
        else {
            return nil
        }

        return number - spellings.count
    }

    // Which row of a link the number stands for, read from the tables that
    // link built.
    //
    // `own` is the document's own declarations by row. A number for one of
    // them answers there: what the document declares is its own whoever else
    // may name it, and a private declaration is in no table of the link's
    // names.
    func row(_ number: Int, rows: [Name: Int], own: [Name: Int], closures: [Int]) -> Answer {
        guard case let .document(spellings, standing) = space else { return .row(number) }
        guard number >= 0, number < spellings.count + standing else { return .unnumbered }

        guard number >= spellings.count else {
            let declared = spellings[number]

            if number >= sent, let row = own[declared] {
                return .row(row)
            }

            return rows[declared].map(Answer.row) ?? .unfound(.sent(declared))
        }

        let nth = number - spellings.count

        guard closures.indices.contains(nth) else { return .unfound(.closure(nth)) }

        return .row(closures[nth])
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
    // the rows they took, which is a list it already holds. A number standing
    // at no row answers nil.
    func answers(rows: [Name: Int], own: [Name: Int]) -> [Int?] {
        guard case .document = space else { return [] }

        return (0..<opening).map { number in
            guard case let .row(row) = row(number, rows: rows, own: own, closures: []) else { return nil }

            return row
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
    // lowering a body it never scanned, and nil past the ones it wrote.
    func closure(_ nth: Int, of declared: Name) -> (number: Int, nth: Int)? {
        guard let run = run(of: declared), nth >= 0, nth < run.count else { return nil }

        return (number: opening + run.start + nth, nth: run.start + nth)
    }

    // MARK: - Private
    // Where a declaration's closures stand among this document's, and how
    // many there are. The runs stand in name order, so a declaration's own
    // begin behind everything the names before it wrote. Nil where the
    // document was never read for that declaration's closures.
    private func run(of declared: Name) -> (start: Int, count: Int)? {
        var standing = 0

        for run in runs {
            guard run.name != declared else { return (start: standing, count: run.count) }

            standing += run.count
        }

        return nil
    }

    private static func read(_ value: Value, of part: String) throws -> [Name: Int] {
        guard case let .array(written) = value else {
            throw ObjectRefused("'\(part)' is not written as a list")
        }

        return try Fields.gathered(try written.map { entry in
            var place = try Fields(entry, of: part)
            let held = (try place.name(), try place.count())

            try place.end()

            return held
        }, of: part)
    }

    private static func placed(_ names: [Name], from start: Int) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = start + entry.offset
        }
    }
}
