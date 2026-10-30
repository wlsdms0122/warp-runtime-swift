//
//  Activation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One body running: its slots, and the frame that says what each slot was
// called, for a refusal that names one. The cells are a value, so a closure
// or a concurrent piece takes its own; the holds among them share their
// boxes.
struct Activation: Sendable {
    // MARK: - Property
    var cells: [Cell]
    let frame: Frame

    // What fills each type parameter of the running body, by label: what the
    // call handed, or what the closure running holds.
    let types: [Name: LoweredType]

    // Which document the running body came from. The numbers the body carries
    // are that document's, so this is what a call reads them against.
    let origin: Int

    // The types the link declared, which a key landing in a dictionary reads.
    let loweredTypes: LoweredTypeTable

    // MARK: - Initializer
    init(_ frame: Frame, of origin: Int, types: [Name: LoweredType] = [:], in loweredTypes: LoweredTypeTable) {
        self.cells = Array(repeating: .value(.null), count: frame.size)
        self.frame = frame
        self.origin = origin
        self.types = types
        self.loweredTypes = loweredTypes
    }

    // MARK: - Public
    // A type a call in this body wrote, with every type parameter of the body
    // read as what fills it here. An associated type the call did not hand,
    // one the signature does not name, is what fills what it stands on gives
    // under its name. One nothing filled stands as it is.
    func reading(_ type: LoweredType) -> LoweredType {
        guard !types.isEmpty, type.namesParameter else { return type }

        let filled = type.parameterLabels.reduce(into: types) { filled, label in
            if filled[label] == nil {
                filled[label] = filling(label)
            }
        }

        return type.replacingParameters(filled)
    }

    // What a slot path holds. The head is never absent, since every slot is
    // there from the frame's making; a hold whose scope changed under it
    // refuses, and every deeper absence is handled inside the walk.
    func value(at address: Address) throws -> Value {
        switch lookup(address) {
        case let .found(value):
            return value

        case let .unfit(reason):
            throw ReferenceUnfit(path: spelled(address), reason: reason)
        }
    }

    // Every index reference read to the value it holds: a write lands on one
    // place, and a hold is extended by places, which the container they
    // reach says the position or the key of.
    func projections(of address: Address) throws -> [Projection] {
        try address.steps.map { step in
            switch step {
            case let .field(position, name, _):
                return .field(position, name)

            case let .name(name, _):
                return .name(name)

            case let .index(index, _):
                return .index(index)

            case let .at(inner, _, coercion):
                let index = try value(at: inner)

                return .index(coercion.map { coercion in coercion.applied(to: index, filling: reading, in: loweredTypes) } ?? index)
            }
        }
    }

    // The path as the author wrote it, for a sentence that reads it back.
    func spelled(_ address: Address) -> Path {
        Path([.name(frame.names[address.slot])] + address.steps.map(spelled))
    }

    // MARK: - Private
    // What fills a type parameter of the running body: what the call handed,
    // or, for an associated type, what fills what it stands on gives under
    // its name.
    private func filling(_ label: Name) -> LoweredType? {
        if let handed = types[label] { return handed }

        guard let associated = AssociatedType(label: label), let base = filling(associated.owner) else { return nil }

        return loweredTypes.typeMember(associated.name, givenBy: base)
    }

    // A dot reads a name and nothing else, and the build judged every one and
    // wrote the judgement into the step. Every slot is there from the frame's
    // making, so a walk comes down on a part or on a reading gone wrong.
    private func lookup(_ address: Address) -> Projection.Part {
        let (slot, steps) = (address.slot, address.steps)
        var current: Value

        do {
            current = try cells[slot].value()
        } catch {
            return .unfit("\(spelled(Address(slot: slot, steps: [])).rendered): \(error)")
        }

        // Whether a marked step met a none, which the path then reads as its
        // Optional's none, promoted or not.
        var metNone = false

        for (index, step) in steps.enumerated() {
            // The path as far as this step, spelled for a refusal. Only a
            // refusal reads it, so a read that lands spells nothing.
            func walked() -> Path {
                spelled(Address(slot: slot, steps: Array(steps[...index])))
            }

            // This step alone, spelled the same way and for the same reader.
            func segment() -> PathSegment {
                spelled(step)
            }

            let projection: Projection

            switch step {
            case let .field(position, name, _):
                projection = .field(position, name)

            case let .name(name, _):
                projection = .name(name)

            case let .index(index, _):
                projection = .index(index)

            // The index is a path of its own, read against the same frame,
            // and lands where the dictionary's key type reads it.
            case let .at(inner, _, coercion):
                switch lookup(inner) {
                case let .found(index):
                    projection = .index(coercion.map { coercion in coercion.applied(to: index, filling: reading, in: loweredTypes) } ?? index)

                case let .unfit(reason):
                    return .unfit(reason)
                }
            }

            metNone = metNone || current.isNone

            switch projection.part(of: current, as: segment, walked: walked) {
            case let .found(value):
                current = value

            case let .unfit(reason):
                return .unfit(reason)
            }
        }

        return .found(address.promoted && !metNone ? current.asSome : current)
    }

    private func spelled(_ step: Step) -> PathSegment {
        switch step {
        case let .field(_, name, optional), let .name(name, optional):
            return .name(name, optional: optional)

        case let .index(index, optional):
            return .index(index, optional: optional)

        case let .at(inner, optional, _):
            return .indexRef(spelled(inner), optional: optional)
        }
    }
}
