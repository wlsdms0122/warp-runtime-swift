//
//  ShapeTable+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension ShapeTable {
    // The declarations as the run reads them. A link says which order its rows
    // stand in, so a document's types and its memberships each take a run of
    // rows the way its declarations do; where nothing says, the declared
    // spellings order them.
    //
    // Both spaces read the order from the same place. A run that stands where
    // its document does is a run a later document cannot move, which is what
    // lets a document already lowered keep the numbers it was lowered with.
    // Either way a row is a row of one table and nothing a link concludes
    // reads one to decide what to say. A name that names itself through a
    // chain of names stands for no shape and lowers to the shape every
    // judgment refuses, so a chain of names is always finite.
    static func lowering(
        _ types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        satisfying: [Name: Set<Name>] = [:],
        unsettled: Requiring? = nil,
        standing: [Name]? = nil,
        constraintStanding: [Name]? = nil,
        of linkage: Linkage
    ) -> ShapeTable {
        // A table of its own even where nothing is declared: a body carried
        // out of such a link holds rows a shared table would let be read
        // elsewhere.
        guard !types.isEmpty || !constraints.isEmpty else {
            return ShapeTable(
                shapes: [],
                constraints: [],
                labels: [],
                constraintLabels: [],
                recordRows: [],
                satisfying: satisfying,
                settled: unsettled == nil,
                unsettled: unsettled,
                of: linkage
            )
        }

        let labels = standing ?? types.keys.sorted()
        let constraintLabels = constraintStanding ?? constraints.keys.sorted()

        // The index first, so a declaration naming another lowers against
        // rows that already exist whichever is declared first.
        let index = ShapeTable(
            shapes: [],
            constraints: [],
            labels: labels,
            constraintLabels: constraintLabels,
            recordRows: [],
            of: linkage
        )

        var shapes = labels.map { label in (types[label] ?? .any).lowered(in: index) }
        let members = constraintLabels.map { label in
            (constraints[label] ?? []).map { member in member.lowered(in: index) }
        }

        // The end of each row's chain of names, or nil where the chain comes
        // back on itself.
        func end(of start: Int) -> Int? {
            var row = start
            var walked: [Int] = [start]

            while let next = shapes[row].row {
                guard !walked.contains(next) else { return nil }

                walked.append(next)
                row = next
            }

            return row
        }

        // Marked before any is replaced, so each row in a cycle is named
        // as itself rather than as whichever the replacement reached first.
        let cycling = shapes.indices.filter { row in end(of: row) == nil }

        for row in cycling {
            shapes[row] = .undeclared(
                label: labels[row].spelling,
                refusal: "type '\(labels[row])', which names itself"
            )
        }

        // The record a row names: the last row on the way to a record shape.
        let recordRows = shapes.indices.map { start -> Int? in
            guard let row = end(of: start), case .record = shapes[row] else { return nil }

            return row
        }

        return ShapeTable(
            shapes: shapes,
            constraints: members,
            labels: labels,
            constraintLabels: constraintLabels,
            recordRows: recordRows,
            cycling: cycling,
            satisfying: satisfying,
            settled: unsettled == nil,
            unsettled: unsettled,
            of: linkage
        )
    }
}
