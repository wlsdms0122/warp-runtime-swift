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
    func written(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(whole)), let (.ranged(.fraction), .int(whole)):
            return .double(Double(whole))

        case let (.named(row), _):
            return table.loweredTypes[row].written(value, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _), let (.inout(inner), _):
            return inner.written(value, in: table)

        case let (.array(element), .array(items)):
            return .array(items.map { item in element.written(item, in: table) })

        case let (.dictionary(entry), .dictionary(entries)):
            return .dictionary(entries.mapValues { _, held in entry.written(held, in: table) })

        case let (.dictionary(entry), .record(record)) where record.name == nil:
            return .record(record.mapValues { _, held in entry.written(held, in: table) })

        case let (.record(declared), .record(record)) where record.name == nil:
            return .record(record.mapValues { name, held in
                declared[name].map { field in field.fieldUnwrapped.written(held, in: table) } ?? held
            })

        default:
            return value
        }
    }

    // The same for an expression written into a place of this type: the
    // literals in it, at the depths a list, a record and the answer of a
    // block or an attempt hand on.
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        if case let .nullable(inner) = self {
            return inner.written(expression, in: table)
        }

        switch expression {
        case let .literal(value):
            return .literal(written(value, in: table))

        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.map { item in element.written(item, in: table) })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, (dotted(name, in: table) ?? .any).written(field, in: table))
                })
            )

        case let .block(block):
            return .block(written(block, in: table))

        case let .attempt(block, rescue):
            return .attempt(written(block, in: table), rescue: written(rescue, in: table))

        default:
            return expression
        }
    }

    // What a reading is once what it reads is written where this is
    // declared: a whole literal standing where this declares a Double is the
    // fraction it names, at whatever depth of a list or a record it stands,
    // the way `written` writes the value itself. Every other reading is what
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

    // A value from outside fitted to this type before it is held to it: a
    // record's fields this does not declare left out, at whatever depth a
    // record, a list, a map or what may be null holds one. The door a host
    // comes through is the one place a value is fitted to a type; everywhere
    // else a place holds a value as it is.
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

    // A block whose answer stands where this is declared.
    func written(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in written(result, in: table) })
    }

    // A closure literal written where this is read, its signature completed
    // by the place: one that writes no `returns`, written where a procedure
    // type says what it answers, answers that, so its body is judged against
    // it and a literal it answers is read as the place reads it. At every
    // depth `written` reaches a literal, so where a closure is written does
    // not decide when what it answers is judged. An answer a call fills is
    // no place's to say, and anything else stands as written.
    func completing(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.completing(expression, in: table)

        case let .named(row):
            return table.loweredTypes[row].completing(expression, in: table)

        default:
            break
        }

        switch expression {
        case let .closure(written):
            guard
                written.signature.returns == nil,
                case let .procedure(_, returns?, _, _) = self,
                let answer = returns.spelled(in: table),
                !answer.isGeneric
            else {
                return expression
            }

            return .closure(written.with(signature: Signature(parameters: written.signature.parameters, returns: answer)))

        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.map { item in element.completing(item, in: table) })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, dotted(name, in: table).map { place in place.completing(field, in: table) } ?? field)
                })
            )

        case let .block(block):
            return .block(completing(block, in: table))

        case let .attempt(block, rescue):
            return .attempt(completing(block, in: table), rescue: completing(rescue, in: table))

        default:
            return expression
        }
    }

    // The same for a block whose answer stands where this is read.
    func completing(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in completing(result, in: table) })
    }
}
