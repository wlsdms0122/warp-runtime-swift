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
    // Where a walk over a path came down: on a value, or on a reading gone
    // wrong. Every slot is there from the frame's making, so there is no
    // third answer.
    private enum Walk {
        case found(Value)
        case unfit(String)
    }

    // MARK: - Property
    var cells: [Cell]
    let frame: Frame

    // Which document the running body came from. The numbers the body carries
    // are that document's, so this is what a call reads them against.
    let origin: Int

    // MARK: - Initializer
    init(_ frame: Frame, of origin: Int) {
        self.cells = Array(repeating: .value(.null), count: frame.size)
        self.frame = frame
        self.origin = origin
    }

    // MARK: - Public
    // What a slot path holds. The head is never absent, since every slot is
    // there from the frame's making; a hold whose scope changed under it
    // refuses, and every deeper absence is answered inside the walk.
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

            case let .at(inner, _):
                return .index(try value(at: inner))
            }
        }
    }

    // The path as the author wrote it, for a sentence that reads it back.
    func spelled(_ address: Address) -> Path {
        Path([.name(frame.names[address.slot])] + address.steps.map(spelled))
    }

    // MARK: - Private
    // A dot reads a name and nothing else, and the build judged every one and
    // wrote the judgement into the step. What may genuinely be absent, a missing
    // entry or a null on the way, is read as null only where the author spelled
    // `?.` or `?[`, and refused everywhere else.
    private func lookup(_ address: Address) -> Walk {
        let (slot, steps) = (address.slot, address.steps)
        var current: Value

        do {
            current = try cells[slot].value()
        } catch {
            return .unfit("\(spelled(Address(slot: slot, steps: [])).rendered): \(error)")
        }

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

            // Null stops every reading the same way, and the rule lives with
            // the segment: the build's walk over types asks the same judge, so
            // the two layers cannot drift apart.
            if current == .null {
                switch segment().meetingNull(at: walked()) {
                case .reads:
                    return .found(.null)

                case let .refused(reason):
                    return .unfit(reason)
                }
            }

            let read: Walk

            switch step {
            case let .index(index, optional):
                read = indexed(current, at: index, optional: optional, walked: walked, segment: segment)

            // The index is a path of its own, read against the same frame.
            case let .at(inner, optional):
                switch lookup(inner) {
                case let .found(index):
                    read = indexed(current, at: index, optional: optional, walked: walked, segment: segment)

                case let .unfit(reason):
                    return .unfit(reason)
                }

            // The place the build proved, which is where a write lands too.
            case let .field(position, _, _):
                guard case let .struct(instance) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.nominal)")
                }

                guard instance.values.indices.contains(position) else {
                    return .unfit("\(walked().rendered) drills past the fields this struct holds")
                }

                read = .found(instance.values[position])

            // A field by its name, of a struct a call decides.
            case let .name(name, _):
                guard case let .struct(instance) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.nominal)")
                }

                guard let next = instance[name] else {
                    return .unfit("\(walked().rendered) drills past the fields this struct holds")
                }

                read = .found(next)
            }

            switch read {
            case let .found(value):
                current = value

            case .unfit:
                return read
            }
        }

        return .found(current)
    }

    // One reading for both index spellings, decided by what is indexed: a
    // list by a position and a map by a key. A list is whatever has
    // elements: the projection owns the `Array<Int>` equation, lazily, so one
    // element read does not unpack a compact spelling. Past the end is a
    // defect, not absence: the list is there and says how long it is. An
    // entry the map does not hold follows the mark.
    private func indexed(
        _ current: Value,
        at index: Value,
        optional: Bool,
        walked: () -> Path,
        segment: () -> PathSegment
    ) -> Walk {
        if case let .dictionary(map) = current {
            guard let entry = map[key: index] else {
                guard optional else {
                    return .unfit(
                        "\(walked().rendered) reads an entry the map does not hold."
                            + " Only `\(segment().mark)` reads absence"
                    )
                }

                return .found(.null)
            }

            return .found(entry)
        }

        guard let elements = current.elements else {
            return .unfit("\(walked().rendered) indexes into \(current.nominal), expected Array or Dictionary")
        }

        guard case let .int(position) = index else {
            return .unfit("\(walked().rendered) indexes a list by \(index.nominal), expected Int")
        }

        guard position >= 0, position < elements.count else {
            return .unfit(
                "\(walked().rendered) indexes a list of \(elements.count) at \(position), a position it does not hold"
            )
        }

        return .found(elements[elements.index(elements.startIndex, offsetBy: position)])
    }

    private func spelled(_ step: Step) -> PathSegment {
        switch step {
        case let .field(_, name, optional), let .name(name, optional):
            return .name(name, optional: optional)

        case let .index(index, optional):
            return .index(index, optional: optional)

        case let .at(inner, optional):
            return .indexRef(spelled(inner), optional: optional)
        }
    }
}
