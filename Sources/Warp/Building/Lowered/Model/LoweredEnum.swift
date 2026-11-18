//
//  LoweredEnum.swift
//  Warp
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// A declared enum's cases as the build laid them out: the enum's name and,
// by each case's name, the fields the case carries, laid out as a struct
// under the case's spelling. A value of the enum is a struct under one of
// those spellings, so the case's layout is exactly the one the value carries.
// Each case takes the enum's type parameters.
struct LoweredEnum: Sendable, Equatable {
    // MARK: - Property
    let name: Name

    let cases: [Name: LoweredStruct]

    // The type parameters, in the order a mention hands their types.
    let typeParameters: [Name]

    // MARK: - Initializer
    init(name: Name, cases: [Name: LoweredStruct], typeParameters: [Name] = []) {
        self.name = name
        self.cases = cases
        self.typeParameters = typeParameters
    }

    // MARK: - Public
    // The fields a case carries, or nil where the enum declares no case under
    // the name.
    subscript(case name: Name) -> LoweredStruct? {
        cases[name]
    }

    // The case a value carries the spelling of, or nil where the value is
    // under no case's spelling.
    func `case`(of instance: Struct) -> LoweredStruct? {
        cases.values.first { held in held.name == instance.name }
    }

    // The enum a mention applying it to `arguments` reads: every case with
    // each type parameter read as the type at its position.
    func applied(to arguments: [LoweredType]) -> LoweredEnum {
        guard !typeParameters.isEmpty else { return self }

        return LoweredEnum(name: name, cases: cases.mapValues { held in held.applied(to: arguments) })
    }

    // The same cases, each field's type put through `transform`.
    func mapCases(_ transform: (LoweredType) throws -> LoweredType) rethrows -> LoweredEnum {
        LoweredEnum(
            name: name,
            cases: try cases.mapValues { held in try held.mapFields(transform) },
            typeParameters: typeParameters
        )
    }

    // MARK: - Private
}
