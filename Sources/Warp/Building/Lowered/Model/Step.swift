//
//  Step.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A path segment as the run reads it. An index written as a name is the slot
// path it reads the position or the key from.
enum Step: Sendable {
    // A field of a struct whose layout the build proved: the place it stands
    // in, which is where a read and a write both land, beside the spelling
    // the path wrote, which is what a sentence calls it.
    case field(Int, Name, optional: Bool)

    // A field read by its name, of a value read through a type parameter,
    // whose type the call decides.
    case name(Name, optional: Bool)

    // What a list or a dictionary holds at this value: a position or a key, by
    // what the run finds there.
    case index(Value, optional: Bool)

    // A position or a key read from a slot, and what becomes of a key where
    // it meets a dictionary whose key reads it another way.
    case at(Address, optional: Bool, coercion: Coercion?)

    // MARK: - Property
    var optional: Bool {
        switch self {
        case let .field(_, _, optional), let .name(_, optional), let .index(_, optional),
            let .at(_, optional, _):
            return optional
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func stand(in standing: inout LoweredBody.Standing) {
        guard case let .at(address, _, _) = self else { return }

        address.stand(in: &standing)
    }

    func rewritten(type: (LoweredType) throws -> LoweredType) rethrows -> Step {
        guard case let .at(address, optional, coercion) = self else { return self }

        return .at(try address.rewritten(type: type), optional: optional, coercion: try coercion?.rewritten(type: type))
    }

    // MARK: - Private
}
