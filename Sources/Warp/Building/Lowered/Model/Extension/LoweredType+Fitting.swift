//
//  LoweredType+Fitting.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

extension LoweredType {
    // A value from outside fitted to this type before it is held to it: a
    // record's fields this does not declare left out, at whatever depth a
    // record, a list, a map or what may be null holds one. Only the doors a
    // host hands a value through fit it to a type; everywhere else a place
    // holds a value as it is.
    func fitted(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.named(row), _):
            return table.loweredTypes[row].fitted(value, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.fitted(value, in: table)

        case let (.array(element), .array(items)):
            return .array(items.map { item in element.fitted(item, in: table) })

        case let (.dictionary(entry), .dictionary(entries)):
            return .dictionary(entries.mapValues { _, held in entry.fitted(held, in: table) })

        case let (.record(declared), .record(record)):
            return .record(
                Record(
                    name: record.name,
                    Dictionary(uniqueKeysWithValues: declared.named.compactMap { name, field in
                        record[name].map { held in (name, field.fieldUnwrapped.fitted(held, in: table)) }
                    })
                )
            )

        case let (.record(declared), .dictionary(entries)):
            return .dictionary(
                Value.Dictionary(
                    Dictionary(uniqueKeysWithValues: declared.named.compactMap { name, field in
                        entries[name].map { held in (name, field.fieldUnwrapped.fitted(held, in: table)) }
                    })
                )
            )

        default:
            return value
        }
    }
}
