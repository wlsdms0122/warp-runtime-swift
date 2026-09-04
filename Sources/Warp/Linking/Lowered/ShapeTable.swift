//
//  ShapeTable.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The declared types and constraints as the run reads them: by row. A
// declared name survives into the run as a row rather than being expanded,
// so a self-naming shape is a shape and not a regress, and a row is read
// by number. The spellings ride along for a refusal and for a record's
// name, and the one lookup by spelling left is a record that arrived under
// an alias, which is resolved once and then carries the canonical spelling.
// A class, so a judgment that recurses passes one reference down rather than
// a copy of every array the table holds.
final class ShapeTable: Sendable {
    // MARK: - Property
    // The declared types, in the order of their spellings.
    let shapes: [Shape]

    // The members of each declared constraint, in the order of their
    // spellings.
    let constraints: [[Shape]]

    let labels: [Name]
    let constraintLabels: [Name]

    // The link this table was built by. A row numbered against it is read
    // where the same link is being read, and nowhere else.
    let linkage: Linkage

    // The row of the record a row names: the last declared name on the way
    // to a record shape, so an alias of a declared record is that record
    // and not a second type. Nil where a row stands for no record.
    let recordRows: [Int?]

    // The rows that name themselves through a chain of names, and so stand
    // for no shape. The lowering is where that is worked out, so it is what
    // says so.
    let circling: [Int]

    private let rows: [Name: Int]
    private let constraintRows: [Name: Int]

    // A table declaring nothing, for a judgment asked with no declarations
    // behind it. It belongs to no link, so no row belongs to it.
    static let empty = ShapeTable(
        shapes: [],
        constraints: [],
        labels: [],
        constraintLabels: [],
        recordRows: [],
        of: .none
    )


    // MARK: - Initializer
    init(
        shapes: [Shape],
        constraints: [[Shape]],
        labels: [Name],
        constraintLabels: [Name],
        recordRows: [Int?],
        circling: [Int] = [],
        of linkage: Linkage
    ) {
        self.shapes = shapes
        self.constraints = constraints
        self.labels = labels
        self.constraintLabels = constraintLabels
        self.recordRows = recordRows
        self.circling = circling
        self.linkage = linkage
        self.rows = Dictionary(uniqueKeysWithValues: labels.enumerated().map { row, label in (label, row) })
        self.constraintRows = Dictionary(
            uniqueKeysWithValues: constraintLabels.enumerated().map { row, label in (label, row) }
        )
    }

    // MARK: - Public
    // The row a spelling declares, or nil where nothing declares it. For
    // lowering a document's type and for a record that arrived under an
    // alias; the run reads rows by number otherwise.
    func row(named name: Name) -> Int? {
        rows[name]
    }

    func constraintRow(named name: Name) -> Int? {
        constraintRows[name]
    }

    // Whether a value is a member of a constraint. A member speaks through
    // the same settlement a declared type applies, so what `int` admits as a
    // slot it admits as a member, widening included. `assuming` is what the
    // caller was already asking; this constraint joins it only where a
    // member has to be settled to answer, since a scalar member answers by
    // kind.
    func admits(constraint row: Int, value: Value, assuming: [Int]) -> Bool {
        constraints[row].contains { member in
            member.admitsAsScalar(value)
                ?? ((try? member.settling(value, at: "member", in: self, assuming: assuming + [row])) != nil)
        }
    }

    // Whether a reading could be a member of a constraint. Membership is
    // one-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about
    // passes here and is judged again where the value arrives.
    //
    // A constrained reading is judged by its own membership rather than by
    // its name: it stands for some member of its constraint, so it fits
    // where every one of those members would.
    func admits(constraint row: Int, reading: Shape, assuming: [Int]) -> Bool {
        switch reading {
        case .any:
            return true

        case let .parameter(_, constraint):
            guard let constraint else { return true }
            guard !assuming.contains(constraint) else { return true }

            return constraints[constraint].allSatisfy { member in
                admits(constraint: row, reading: member, assuming: assuming + [constraint])
            }

        // Nothing can be said about a reading the table does not answer, so
        // it passes here and is refused where the name is met.
        case .undeclared:
            return true

        default:
            return constraints[row].contains { member in member.accepts(reading, in: self) }
        }
    }

    // The same membership asked of a document's reading by the constraint's
    // spelling, for the link's walk. Nil where nothing declares the
    // constraint.
    func admits(constraint name: Name, reading: TypeExpression) -> Bool? {
        guard let row = constraintRow(named: name) else { return nil }

        return admits(constraint: row, reading: reading.lowered(in: self), assuming: [])
    }

    // The record a shape names through the row it stands on, or nil where it
    // names none. The one reading of `recordRows` for a shape that is not
    // itself a row.
    func record(of shape: Shape) -> Int? {
        shape.row.flatMap { row in recordRows[row] }
    }

    // MARK: - Private
}
