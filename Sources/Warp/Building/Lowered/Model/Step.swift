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

    // What a list or a map holds at this value: a position or a key, by
    // what the run finds there.
    case index(Value, optional: Bool)

    case at(Address, optional: Bool)

    // MARK: - Property
    var optional: Bool {
        switch self {
        case let .field(_, _, optional), let .name(_, optional), let .index(_, optional),
            let .at(_, optional):
            return optional
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func stand(in standing: inout LoweredBody.Standing) {
        guard case let .at(address, _) = self else { return }

        address.stand(in: &standing)
    }

    // MARK: - Private
}
