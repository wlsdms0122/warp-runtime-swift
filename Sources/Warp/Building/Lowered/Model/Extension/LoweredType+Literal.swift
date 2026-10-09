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
    // names, and a nameless record where a declared record is read takes
    // its name, at whatever depth of a list or a record it stands.
    // Everything else is the value as written, and whether it fits is the
    // judge's to say.
    func written(_ value: Value, in table: LoweredTypeTable) -> Value {
        switch (self, value) {
        case let (.double, .int(whole)):
            return .double(Double(whole))

        case let (.named(row), _):
            let written = table.loweredTypes[row].written(value, in: table)

            guard let nominal = table.record(of: self), case let .record(record) = written, record.name == nil else {
                return written
            }

            return .record(record.named(table.labels[nominal]))

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
    // block or an attempt hand on. A record built from parts there takes
    // the name where it is built (`naming`).
    func written(_ expression: Expression, in table: LoweredTypeTable) -> Expression {
        reaching(expression, at: nil, in: table) { place, standing, _ in
            guard case let .literal(value) = standing else { return nil }

            return .literal(place.written(value, in: table))
        }
    }

    // The records an expression written into a place of this type builds
    // where a declared record is read, by the place each is built at, with
    // the name it takes there: the build held each part to its field, so
    // the record is the declared one and the run builds it under the name,
    // with nothing to cast. What builds no record is not walked, so its place
    // is never spelled.
    func naming(_ expression: Expression, at place: @autoclosure () -> Place, in table: LoweredTypeTable) -> [Place: Name] {
        switch expression {
        case .record, .array, .block, .attempt, .loop:
            break

        default:
            return [:]
        }

        var names: [Place: Name] = [:]

        _ = reaching(expression, at: place(), in: table) { type, standing, place in
            if case .record = standing, case .named = type, let nominal = table.record(of: type), let place {
                names[place] = table.labels[nominal]
            }

            return nil
        }

        return names
    }

    // The same for a block standing at a place, whose answer stands where
    // this is read.
    func naming(_ block: Block, at place: @autoclosure () -> Place, in table: LoweredTypeTable) -> [Place: Name] {
        block.result.map { result in naming(result, at: place().child(.result), in: table) } ?? [:]
    }

    // What a reading is once what it reads is written where this is
    // declared: a whole literal standing where this declares a Double is the
    // fraction it names, at whatever depth of a list or a record it stands,
    // the way `written` writes the value itself. Every other reading is what
    // it was.
    func written(_ reading: LoweredType, in table: LoweredTypeTable) -> LoweredType {
        switch (self, reading) {
        case (.double, .wholeLiteral):
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
        reaching(expression, at: nil, in: table) { place, standing, _ in
            guard case let .closure(written) = standing else { return nil }

            guard written.signature.returns == nil, case let .procedure(_, returns?, _, _) = place else { return standing }

            let answer = returns.spelled(in: table)

            guard !answer.isGeneric else { return standing }

            return .closure(written.with(signature: Signature(parameters: written.signature.parameters, returns: answer)))
        }
    }

    // The same for a block whose answer stands where this is read.
    func completing(_ block: Block, in table: LoweredTypeTable) -> Block {
        Block(body: block.body, result: block.result.map { result in completing(result, in: table) })
    }

    // The walk `written`, `completing` and `naming` share: an expression
    // standing where this is read, through what may be null and the names
    // around it, at the depths a list, a record and the answer of a block, an
    // attempt or a loop hand on, each at its place where one is asked for.
    // `replacing` is asked first at each depth, with the type read there, and
    // answers what stands in place of the expression, or nil to walk on.
    private func reaching(
        _ expression: Expression,
        at place: Place?,
        in table: LoweredTypeTable,
        replacing: (LoweredType, Expression, Place?) -> Expression?
    ) -> Expression {
        func answering(_ block: Block, at place: Place?) -> Block {
            Block(
                body: block.body,
                result: block.result.map { result in reaching(result, at: place?.child(.result), in: table, replacing: replacing) }
            )
        }

        // What a block, an attempt or a loop answers stands where this is
        // read, so it is walked with this type as it stands, a name around
        // it included.
        switch expression {
        case let .block(block):
            return .block(answering(block, at: place?.child(.held)))

        case let .attempt(block, rescue):
            return .attempt(answering(block, at: place?.child(.held)), rescue: answering(rescue, at: place?.child(.rescue)))

        case let .loop(condition, body):
            return .loop(while: condition, body: answering(body, at: place?.child(.held)))

        default:
            break
        }

        switch self {
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.reaching(expression, at: place, in: table, replacing: replacing)

        // A declared record is asked as itself before what it stands for, so
        // what writes a literal there knows the name it is written into.
        case let .named(row):
            if table.recordRows[row] != nil, let standing = replacing(self, expression, place) {
                return standing
            }

            return table.loweredTypes[row].reaching(expression, at: place, in: table, replacing: replacing)

        default:
            break
        }

        if let standing = replacing(self, expression, place) {
            return standing
        }

        switch expression {
        case let .array(items):
            guard let element = element(in: table) else { return expression }

            return .array(items.enumerated().map { position, item in
                element.reaching(item, at: place?.child(.element(position)), in: table, replacing: replacing)
            })

        case let .record(fields):
            return .record(
                Dictionary(uniqueKeysWithValues: fields.map { name, field in
                    (name, dotted(name, in: table).map { dotted in
                        dotted.reaching(field, at: place?.child(.field(name)), in: table, replacing: replacing)
                    } ?? field)
                })
            )

        default:
            return expression
        }
    }
}
