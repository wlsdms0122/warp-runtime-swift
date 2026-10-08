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

    // Every index reference read to a position, or to a key where the
    // container is a map: a write lands on one place, and a hold is extended
    // by places.
    func projections(of address: Address) throws -> [Projection] {
        try address.steps.map { step in
            switch step {
            case let .field(position, name, _):
                return .field(position, name)

            case let .key(name, _):
                return .key(name)

            case let .index(index, _):
                return .index(index)

            case let .at(inner, _):
                switch try value(at: inner) {
                case let .int(index):
                    return .index(index)

                // A dictionary's names are data, so a key the run settled
                // writes an entry the way a written key does.
                case let .string(key):
                    guard let name = try? Name(key) else {
                        throw ExecutionError(
                            "'\(spelled(address).rendered)' writes under '\(key)', which is not a name"
                        )
                    }

                    return .key(name)

                default:
                    throw ExecutionError(
                        "'\(spelled(address).rendered)' indexes with"
                            + " '\(spelled(inner).rendered)', which is not an Int or a String"
                    )
                }
            }
        }
    }

    // The path as the author wrote it, for a sentence that reads it back.
    func spelled(_ address: Address) -> Path {
        Path([.key(frame.names[address.slot])] + address.steps.map(spelled))
    }

    // MARK: - Private
    // A dot reads a name and nothing else, and the build judged every one and
    // wrote the judgment into the step. What may genuinely be absent, a missing
    // entry or a null on the way, is read as null only where the author spelled
    // `?.`, and refused everywhere else.
    private func lookup(_ address: Address) -> Walk {
        let (slot, steps) = (address.slot, address.steps)
        var current: Value

        do {
            current = try cells[slot].value()
        } catch {
            return .unfit("\(error)")
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
            case let .index(index, _):
                read = indexed(current, at: index, walked: walked)

            // The name is a path of its own, read against the same frame.
            case let .at(inner, optional):
                func name() -> String {
                    spelled(inner).rendered
                }

                switch lookup(inner) {
                case let .found(.int(index)):
                    read = indexed(current, at: index, walked: walked)

                // A dictionary's names are data, so a key the run settled
                // reads an entry the way a written key does.
                case let .found(.string(key)):
                    read = keyed(
                        current,
                        at: key,
                        optional: optional,
                        walked: walked,
                        segment: segment
                    )

                case let .found(.double(double)):
                    switch IntNarrowing(double) {
                    case let .int(index):
                        read = indexed(current, at: index, walked: walked)

                    case .notANumber, .fractional:
                        return .unfit("index reference \(name()) is not a whole number")

                    case .overflow:
                        return .unfit(
                            "index reference \(name()) indexes past the end of any array"
                        )
                    }

                case let .found(value):
                    return .unfit(
                        "index reference \(name()) is \(value.type), expected Int or String"
                    )

                case let .unfit(reason):
                    return .unfit(reason)
                }

            // The place the build proved, which is where a write lands too.
            case let .field(position, _, _):
                guard case let .record(record) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard record.values.indices.contains(position) else {
                    return .unfit("\(walked().rendered) drills past the fields this record holds")
                }

                read = .found(record.values[position])

            case let .key(key, optional):
                guard current.holdsFields else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard let next = current[key] else {
                    guard optional else {
                        return .unfit(
                            "\(walked().rendered): '\(key)' is not there."
                                + " Only `\(segment().mark)` reads absence"
                        )
                    }

                    return .found(.null)
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

    // One reading for both index spellings. What is indexed is whatever has
    // elements: the projection owns the `Array<Int>` equation, lazily, so
    // one element read does not unpack a compact spelling. Past the end is a
    // defect, not absence: the array is there and says how long it is.
    private func indexed(_ current: Value, at index: Int, walked: () -> Path) -> Walk {
        guard let elements = current.elements else {
            return .unfit("\(walked().rendered) indexes into \(current.type), expected array")
        }

        guard index >= 0, index < elements.count else {
            return .unfit(
                "\(walked().rendered) indexes past the end of \(elements.count) element(s)"
            )
        }

        return .found(elements[elements.index(elements.startIndex, offsetBy: index)])
    }

    // One reading for a key the run settled. What is keyed is whatever holds
    // fields, and an absent entry follows the mark the way a written key does.
    private func keyed(
        _ current: Value,
        at key: String,
        optional: Bool,
        walked: () -> Path,
        segment: () -> PathSegment
    ) -> Walk {
        guard current.holdsFields else {
            return .unfit("\(walked().rendered) drills a field into \(current.type)")
        }

        guard let name = try? Name(key) else {
            return .unfit("\(walked().rendered) reads '\(key)', which is not a name")
        }

        guard let next = current[name] else {
            guard optional else {
                return .unfit(
                    "\(walked().rendered): '\(key)' is not there."
                        + " Only `\(segment().mark)` reads absence"
                )
            }

            return .found(.null)
        }

        return .found(next)
    }

    private func spelled(_ step: Step) -> PathSegment {
        switch step {
        case let .field(_, name, optional), let .key(name, optional):
            return .key(name, optional: optional)

        case let .index(index, optional):
            return .index(index, optional: optional)

        case let .at(inner, optional):
            return .indexRef(spelled(inner), optional: optional)
        }
    }
}
