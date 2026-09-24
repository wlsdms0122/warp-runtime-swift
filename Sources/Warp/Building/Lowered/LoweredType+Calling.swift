//
//  LoweredType+Calling.swift
//  Warp
//
//  Created by JSilver on 9/24/26.
//

import Foundation

// Whether a value read as this type could be a procedure: the question a
// call of a value asks before the run. A reading no procedure could stand in
// is a call every run refuses.
extension LoweredType {
    func couldBeProcedure(in table: LoweredTypeTable) -> Bool {
        couldBeProcedure(in: table, assuming: [])
    }

    // Names are peeled one layer at a time, with the rows already being asked
    // about remembered, since a membership may name itself through a row.
    private func couldBeProcedure(in table: LoweredTypeTable, assuming: [Int]) -> Bool {
        switch self {
        case .procedure, .any, .never, .reading, .undeclared:
            return true

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.couldBeProcedure(in: table, assuming: assuming)

        case let .named(row):
            guard !assuming.contains(row) else { return false }

            return table.loweredTypes[row].couldBeProcedure(in: table, assuming: assuming + [row])

        // A value of a type parameter or a composition is one of every
        // bound's members at once. A contract is answered by declared types,
        // and a procedure wears no name to answer one.
        case let .parameter(_, bounds), let .composition(bounds):
            return bounds.allSatisfy { bound in
                switch bound {
                case let .membership(row):
                    return table.constraints[row].contains { member in
                        member.couldBeProcedure(in: table, assuming: assuming)
                    }

                case .contract:
                    return false
                }
            }

        case .null, .bool, .int, .double, .string, .ranged, .array, .dictionary, .record:
            return false
        }
    }
}
