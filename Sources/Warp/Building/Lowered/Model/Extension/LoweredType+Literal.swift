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
    // block or an attempt hand on. A record literal written where a declared
    // record is read takes the record's name here: one written whole is the
    // named value, and one built from parts is the cast to the record, which
    // stands, since the build held each part to its field.
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, in: table) { place, standing in
            if let nominal = table.record(of: place) {
                let label = table.labels[nominal]
                let declared = table.loweredTypes[nominal]

                switch standing {
                case let .literal(.record(record)) where record.name == nil:
                    guard case let .record(fields) = declared.written(.record(record), in: table) else { return nil }

                    return .literal(.record(fields.named(label)))

                case .record:
                    return .cast(declared.written(standing, in: table), as: .named(label), optional: false)

                default:
                    return nil
                }
            }

            guard case let .literal(value) = standing else { return nil }

            return .literal(place.written(value, in: table))
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

    // A block whose answer stands where this is declared.
    func written(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in written(result, in: table) })
    }

    // A closure literal written where this is read, its signature completed
    // by the place: one that writes no `returns`, written where a procedure
    // type says what it answers, answers that, so its body is judged against
    // it and a literal it answers is read as the place reads it. It reaches
    // every depth a literal is written at, so where a closure is written does
    // not decide when what it answers is judged. An answer a call fills is no
    // place's to say, and anything else stands as written.
    func completing(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, in: table) { place, standing in
            guard case let .closure(written) = standing else { return nil }

            guard
                written.signature.returns == nil,
                case let .procedure(_, returns?, _, _) = place,
                let answer = returns.spelled(in: table),
                !answer.isGeneric
            else {
                return standing
            }

            return .closure(written.with(signature: Signature(parameters: written.signature.parameters, returns: answer)))
        }
    }

    // The same for a block whose answer stands where this is read.
    func completing(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in completing(result, in: table) })
    }

    // MARK: - Private
    // The walk `written` and `completing` share: an expression standing where
    // this is read, through what may be null and the names around it, at the
    // depths a list, a record and the answer of a block or an attempt hand on.
    // `replacing` is asked first at each depth, with the type read there, and
    // answers what stands in place of the expression, or nil to walk on.
    private func reaching(
        _ expression: Expression,
        in table: LoweredTypeTable,
        replacing: (LoweredType, Expression) -> Expression?
    ) -> Expression {
        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reaching(expression, in: table, replacing: replacing)

        // A declared record is asked as itself before what it stands for, so
        // what writes a literal there knows the name it is written into.
        case let .named(row):
            if table.recordRows[row] != nil, let standing = replacing(self, expression) {
                return standing
            }

            return table.loweredTypes[row].reaching(expression, in: table, replacing: replacing)

        default:
            break
        }

        if let standing = replacing(self, expression) {
            return standing
        }

        func answering(_ block: Block) -> Block {
            Block(body: block.body, result: block.result.map { result in reaching(result, in: table, replacing: replacing) })
        }

        switch expression {
        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.map { item in element.reaching(item, in: table, replacing: replacing) })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, dotted(name, in: table).map { place in place.reaching(field, in: table, replacing: replacing) } ?? field)
                })
            )

        case let .block(block):
            return .block(answering(block))

        case let .attempt(block, rescue):
            return .attempt(answering(block), rescue: answering(rescue))

        default:
            return expression
        }
    }
}
