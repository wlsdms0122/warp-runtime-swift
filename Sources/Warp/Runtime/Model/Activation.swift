//
//  Activation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// One body running: its slots, what each slot was called, for a refusal
// that names one, and where the frame was entered from, for a trace. The
// cells are a value, so a closure or a concurrent piece takes its own; the
// holds among them share their boxes.
struct Activation: Sendable {
    // MARK: - Property
    var cells: [Cell]
    let names: [Name]

    // What fills each type parameter of the running body, by label: what the
    // call handed, or what the closure running holds.
    let types: [Name: LoweredType]

    // Which document the running body came from. The numbers the body carries
    // are that document's, so this is what a call reads them against.
    let origin: Int

    // The types the link declared, which a key landing in a dictionary reads.
    let loweredTypes: LoweredTypeTable

    // Where the run stood when it entered this frame, and the hop entering
    // took, or none for the frame a run or a fold starts in.
    let caller: Location
    let hop: Trace.Hop?

    // The round each loop running in this frame is on, by how deep the loop
    // stands among the loops around it here. A loop writes its own depth as
    // each round starts, so a depth past the loops running now holds what a
    // loop that ended left.
    var rounds: [Int] = []

    // The frame's link, made the first time something below the frame reads
    // where it stands, and kept for every read after.
    private var link: FrameLink?

    // Argument lists a native call in this frame handed back once it was
    // over, so the next call writes every position of one rather than making
    // one. A call reached while another is reading its arguments takes its
    // own.
    private var spareArguments: [[Value?]] = []

    // MARK: - Initializer
    // Every slot null but the constants the body reads, which hold their
    // values from the body's start.
    init(
        _ frame: Frame,
        of origin: Int,
        types: [Name: LoweredType] = [:],
        in loweredTypes: LoweredTypeTable,
        caller: Location = .trace(Trace()),
        hop: Trace.Hop? = nil
    ) {
        var cells = Array(repeating: Cell.value(.null), count: frame.size)

        for (value, slot) in frame.constants {
            cells[slot] = .value(value)
        }

        self.init(
            cells: cells,
            names: frame.names,
            types: types,
            origin: origin,
            in: loweredTypes,
            caller: caller,
            hop: hop
        )
    }

    // A frame whose slots the caller already filled.
    init(
        cells: [Cell],
        names: [Name],
        types: [Name: LoweredType],
        origin: Int,
        in loweredTypes: LoweredTypeTable,
        caller: Location,
        hop: Trace.Hop?
    ) {
        self.cells = cells
        self.names = names
        self.types = types
        self.origin = origin
        self.loweredTypes = loweredTypes
        self.caller = caller
        self.hop = hop
    }

    // MARK: - Public
    // A type a call in this body wrote, with every type parameter of the body
    // read as what fills it here. An associated type the call did not hand,
    // one the signature does not name, is what fills what it stands on gives
    // under its name. One nothing filled stands as it is.
    func reading(_ type: LoweredType) -> LoweredType {
        Self.reading(type, filledBy: types, in: loweredTypes)
    }

    // The same reading in a body `types` fills, made wherever those types
    // are known.
    static func reading(
        _ type: LoweredType,
        filledBy types: [Name: LoweredType],
        in loweredTypes: LoweredTypeTable
    ) -> LoweredType {
        guard !types.isEmpty, type.namesParameter else { return type }

        let filled = type.parameterLabels.reduce(into: types) { filled, label in
            if filled[label] == nil {
                filled[label] = filling(label, from: types, in: loweredTypes)
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
            throw PathRefused(path: spelled(address), reason: reason)
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

    // The value a slot holds, moved out of it, so what it is handed to holds
    // it alone. The slot holds null until the statement reading it writes it.
    mutating func take(_ slot: Int) throws -> Value {
        let value = try cells[slot].value()

        cells[slot] = .value(.null)

        return value
    }

    // Writes the part of the value a slot holds that the path names. The
    // value is read once, rewritten, and stored once. A refusal names the
    // path by what its indexes read, as a write through a hold does.
    mutating func write(_ value: Value, at address: Address) throws {
        let projections = try projections(of: address)
        let written = try cells[address.slot].value().writing(value, at: projections) {
            Path([.name(names[address.slot])] + projections.map(\.spelled)).rendered
        }

        cells[address.slot] = .value(written)
    }

    // The path as the author wrote it, for a sentence that reads it back.
    func spelled(_ address: Address) -> Path {
        Path([.name(names[address.slot])] + address.steps.map(spelled))
    }

    // Where the run stands at a statement of this frame, or at the frame
    // itself where no statement is running.
    mutating func location(at site: Site?) -> Location {
        let link = linked()

        guard let site else { return .entered(link) }

        return .running(link, site, rounds: rounds)
    }

    // The trace of the run at a statement of this frame, built now.
    mutating func trace(at site: Site?) -> Trace {
        location(at: site).trace
    }

    // An argument list for a native call to fill, `count` long, each
    // position written over by the call.
    mutating func arguments(count: Int) -> [Value?] {
        guard var spare = spareArguments.popLast() else {
            return Array(repeating: nil, count: count)
        }

        while spare.count < count {
            spare.append(nil)
        }

        if spare.count > count {
            spare.removeLast(spare.count - count)
        }

        return spare
    }

    // An argument list a native call is done with, kept for the next one.
    // One the procedure kept hold of is copied when it is next written, so
    // what the procedure kept is never changed.
    mutating func handBack(_ arguments: consuming [Value?]) {
        spareArguments.append(arguments)
    }

    // MARK: - Private
    private mutating func linked() -> FrameLink {
        if let link { return link }

        let made = FrameLink(caller: caller, hop: hop)

        link = made

        return made
    }

    // What fills a type parameter of the running body: what the call handed,
    // or, for an associated type, what fills what it stands on gives under
    // its name.
    private static func filling(
        _ label: Name,
        from types: [Name: LoweredType],
        in loweredTypes: LoweredTypeTable
    ) -> LoweredType? {
        if let handed = types[label] { return handed }

        guard
            let associated = AssociatedType(label: label),
            let base = filling(associated.owner, from: types, in: loweredTypes)
        else { return nil }

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

        for (index, step) in steps.enumerated() {
            // A marked step meeting a none reads null for the whole path, so
            // the steps from here read nothing and nothing is promoted.
            if step.optional, current.isNone {
                return .found(.null)
            }

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

            switch projection.part(of: current, as: segment, walked: walked) {
            case let .found(value):
                current = value

            case let .unfit(reason):
                return .unfit(reason)
            }
        }

        return .found(address.promoted ? current.asSome : current)
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
