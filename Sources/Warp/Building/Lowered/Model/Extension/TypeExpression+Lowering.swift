//
//  TypeExpression+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension TypeExpression {
    // This type as the run reads it, with every declared name resolved: a
    // struct to its row, and an alias to what it stands for. A name nothing
    // declares, a bound naming no contract and `Self` outside a contract
    // stand for no type, so each lowers to `Never`. A build refuses the first
    // two in every document and object before it reads a lowering, and a
    // table a host builds is held to the same judge; the load refuses the
    // third in a document, and an object writing it there reads it as
    // `Never`. `bounds` are what the signature this type is written in holds
    // each type parameter and each associated type of one to, by its name,
    // and `sameTypes` the associated types it says are a type.
    func lowered(
        in table: LoweredTypeTable,
        bounds: [Name: Set<Name>] = [:],
        sameTypes: [Name: TypeExpression] = [:]
    ) -> LoweredType {
        // A part, read under the same signature.
        func part(_ type: TypeExpression) -> LoweredType {
            type.lowered(in: table, bounds: bounds, sameTypes: sameTypes)
        }

        switch self {
        case .any:
            return .any

        case .never:
            return .never

        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case let .array(element):
            return .array(part(element))

        case let .dictionary(key, value):
            return .dictionary(key: part(key), value: part(value))

        case let .procedure(type, constness, isolation):
            return .procedure(
                type.map { type in
                    LoweredProcedureType(
                        parameters: type.parameters.map(part),
                        returns: type.returns.map(part),
                        failing: type.failing
                    )
                },
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(part(inner))

        case let .inout(inner):
            return .inout(part(inner))

        case let .nullable(inner):
            return part(inner).admittingNull

        // Types and contracts are two tables and no name is in both, so a
        // mention is looked for in each. A contract standing as a type is a
        // value of whatever answers it.
        // A struct applied to types is the row and what it is applied to.
        case let .named(name, arguments):
            if let row = table.row(named: name) {
                return table.mention(of: row).applied(to: arguments.map(part))
            }

            guard table.declaresContract(name) else { return .never }

            return .composition([name])

        // A bound names a contract.
        case let .parameter(name):
            return lowered(bounds: bounds[name] ?? [], in: table) { bounds in .parameter(label: name, bounds: bounds) }

        case let .composition(names):
            return lowered(bounds: names, in: table, as: LoweredType.composition)

        case let .projection(of, path):
            return .projection(of: of, path: path)

        // An associated type is a type parameter of its own, labelled as it is
        // written, which what fills what it stands on decides. The contracts
        // bounding that say what holds it, the signature may say more, and
        // where the signature says it is a type it is that type. One no
        // contract bounding it asks stands for no type, which the build
        // refuses where it is written.
        case let .associatedType(of, name):
            let label = name.spelled(under: of)

            if let same = sameTypes[label] {
                return same.lowered(in: table, bounds: bounds, sameTypes: sameTypes.filter { key, _ in key != label })
            }

            guard let asked = table.bounds(of: name, askedBy: table.contracts(bounding: of, under: bounds)) else {
                return .never
            }

            return lowered(bounds: asked.union(bounds[label] ?? []), in: table) { bounds in
                .parameter(label: label, bounds: bounds)
            }

        // A contract's procedures read `Self` before anything lowers them, so
        // what is left is `Self` written where no contract stands, which is
        // refused where it was written.
        case .selfType:
            return .never
        }
    }

    // What a set of names stands for: the contracts, in the one order a set
    // of bounds is written in, or `Never` where a name is no contract.
    private func lowered(
        bounds names: some Collection<Name>,
        in table: LoweredTypeTable,
        as bounded: ([Name]) -> LoweredType
    ) -> LoweredType {
        guard names.allSatisfy(table.declaresContract) else { return .never }

        return bounded(names.sorted())
    }
}
