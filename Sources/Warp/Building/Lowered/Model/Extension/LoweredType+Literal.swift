//
//  LoweredType+Literal.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

extension LoweredType {
    // A value written as a literal, as a place of this type holds it: each
    // whole number standing where this declares a Double is the fraction it
    // names, at whatever depth of a list or a record it stands. Everything
    // else is the value as written, and whether it fits is the judge's to
    // say.
    func literal(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(whole)), let (.ranged(.fraction), .int(whole)):
            return .double(Double(whole))

        case let (.named(row), _):
            return table.loweredTypes[row].literal(value, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.literal(value, in: table)

        case let (.array(element), .array(items)):
            return .array(items.map { item in element.literal(item, in: table) })

        case let (.dictionary(entry), .dictionary(entries)):
            return .dictionary(entries.mapValues { _, held in entry.literal(held, in: table) })

        case let (.dictionary(entry), .record(record)) where record.name == nil:
            return .record(record.mapValues { _, held in entry.literal(held, in: table) })

        case let (.record(declared), .record(record)) where record.name == nil:
            return .record(record.mapValues { name, held in
                declared[name].map { field in field.fieldUnwrapped.literal(held, in: table) } ?? held
            })

        default:
            return value
        }
    }

    // The same for an expression written into a place of this type: the
    // literals in it, at the depths a list, a record and the answer of a
    // block or an attempt hand on.
    func literal(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        if case let .nullable(inner) = self {
            return inner.literal(expression, in: table)
        }

        switch expression {
        case let .literal(value):
            return .literal(literal(value, in: table))

        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.map { item in element.literal(item, in: table) })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, (dotted(name, in: table) ?? .any).literal(field, in: table))
                })
            )

        case let .block(block):
            return .block(literal(block, in: table))

        case let .attempt(block, rescue):
            return .attempt(literal(block, in: table), rescue: literal(rescue, in: table))

        default:
            return expression
        }
    }

    // What a reading is once what it reads is written where this is
    // declared: a whole literal standing where this declares a Double is the
    // fraction it names, at whatever depth of a list or a record it stands,
    // the way `literal` writes the value itself. Every other reading is what
    // it was.
    func written(_ reading: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        switch (self, reading) {
        case (.double, .wholeLiteral), (.ranged(.fraction), .wholeLiteral):
            return .double

        case let (.named(row), _):
            return table.loweredTypes[row].written(reading, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(reading, in: table)

        case let (.array(element), .array(read)):
            return .array(element.written(read, in: table))

        case let (.dictionary(entry), .dictionary(read)):
            return .dictionary(entry.written(read, in: table))

        case let (.dictionary(entry), .record(read)) where read.layout.name == nil:
            return .record(LoweredRecord(layout: read.layout, fields: read.fields.map { field in entry.written(field, in: table) }))

        case let (.record(declared), .record(read)) where read.layout.name == nil:
            return .record(
                LoweredRecord(
                    layout: read.layout,
                    fields: read.named.map { name, field in
                        declared[name].map { place in place.fieldUnwrapped.written(field, in: table) } ?? field
                    }
                )
            )

        default:
            return reading
        }
    }

    // A block whose answer stands where this is declared.
    func literal(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in literal(result, in: table) })
    }
}
