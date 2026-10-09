//
//  LoweredType+Fitting.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

extension LoweredType {
    // A value from outside fitted to this type before it is held to it: a
    // record's fields this does not declare left out, and a nameless record
    // or a map of fields where a declared record is read named by it, at
    // whatever depth a record, a list, a map or what may be null holds one.
    // Only the doors a host hands a value through fit it to a type.
    func fitted(_ value: Value, in table: LoweredTypeTable) -> Value {
        shaped(value, leavingOut: true, in: table)
    }

    // A value from outside at the door it comes through, fitted to this type
    // and then judged against it: the one rule every door keeps.
    func settling(
        outside value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        try settling(fitted(value, in: table), at: path(), in: table)
    }

    // A value a cast reads, named the way this type names it: a nameless
    // record or a map of fields where a declared record is read takes the
    // record's name, at the same depths, and keeps every field it holds.
    // Whether it fits is the judge's to say. A cast and the doors are the
    // only places that write a name onto a value the run holds; a slot
    // judging a value writes none.
    func named(_ value: Value, in table: LoweredTypeTable) -> Value {
        shaped(value, leavingOut: false, in: table)
    }

    // The walk the two share.
    private func shaped(_ value: Value, leavingOut: Bool, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.named(row), _):
            let shaped = table.loweredTypes[row].shaped(value, leavingOut: leavingOut, in: table)

            guard let nominal = table.record(of: self) else { return shaped }

            switch shaped {
            case let .record(record) where record.name == nil:
                return .record(record.named(table.labels[nominal]))

            case let .dictionary(entries):
                return .record(
                    Record(
                        name: table.labels[nominal],
                        Dictionary(uniqueKeysWithValues: entries.names.compactMap { name in entries[name].map { held in (name, held) } })
                    )
                )

            default:
                return shaped
            }

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.shaped(value, leavingOut: leavingOut, in: table)

        case let (.array(element), .array(items)) where element.reachesRecord:
            return .array(items.map { item in element.shaped(item, leavingOut: leavingOut, in: table) })

        case let (.dictionary(entry), .dictionary(entries)) where entry.reachesRecord:
            return .dictionary(entries.mapValues { _, held in entry.shaped(held, leavingOut: leavingOut, in: table) })

        // A nameless record read as a map holds its entries as fields.
        case let (.dictionary(entry), .record(record)) where entry.reachesRecord:
            return .record(Record(name: record.name, Dictionary(uniqueKeysWithValues: record.names.compactMap { name in
                record[name].map { held in (name, entry.shaped(held, leavingOut: leavingOut, in: table)) }
            })))

        case let (.record(declared), .record(record)):
            return .record(Record(name: record.name, fields(record.names, of: { name in record[name] }, along: declared, leavingOut: leavingOut, in: table)))

        case let (.record(declared), .dictionary(entries)):
            return .dictionary(Value.Dictionary(fields(entries.names, of: { name in entries[name] }, along: declared, leavingOut: leavingOut, in: table)))

        default:
            return value
        }
    }

    // Whether a value of this may hold a record, which is all the walk
    // writes or leaves out: what holds none comes back as it is, unwalked.
    var reachesRecord: Bool {
        switch self {
        case .named, .record:
            return true

        case let .array(inner), let .dictionary(inner), let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reachesRecord

        default:
            return false
        }
    }

    // The fields a record or a map holds, shaped along a record type: each
    // the type declares by its field's type, and each it does not kept or
    // left out.
    private func fields(
        _ names: [Name],
        of read: (Name) -> Value?,
        along declared: LoweredRecord,
        leavingOut: Bool,
        in table: LoweredTypeTable
    ) -> [Name: Value] {
        Dictionary(uniqueKeysWithValues: names.compactMap { name in
            guard let held = read(name) else { return nil }
            guard let field = declared[name] else { return leavingOut ? nil : (name, held) }

            return (name, field.fieldUnwrapped.shaped(held, leavingOut: leavingOut, in: table))
        })
    }
}
