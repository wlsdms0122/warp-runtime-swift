//
//  Flow.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// What ran inside an expression may have written the enclosing names or taken
// their boxes. The one thing a nested body does that the body around it has to
// know about, because a write is to a box the enclosing body holds. A flow
// holds the way that goes on past the expression, and the ways that left it,
// each kept by where its leave lands until the construct it lands at takes it
// back.
struct Flow {
    // Where ways that each held one box meet: what the box is held to after,
    // given the name and the type each way held it to. Which type that is is a
    // judgement of types, and the walk that asks for a meeting makes it.
    typealias Meeting = (Name, LoweredType, LoweredType) throws -> LoweredType

    // Where a way that left lands: the procedure (`return`), the end of a
    // loop (`break`), the end of a round (`continue`), each by the loop it
    // names or nothing for the nearest, or the attempt around it (a failure).
    enum Reach: Hashable {
        case procedure
        case loop(Name?)
        case round(Name?)
        case failure

        // MARK: - Initializer
        init(_ leave: Leave) {
            switch leave.reach {
            case .procedure: self = .procedure
            case .construct: self = .loop(leave.target)
            case .round: self = .round(leave.target)
            }
        }

        // MARK: - Public
        // Whether this ends a round of the loop under this name, which the
        // next round starts from: a `continue` naming it, or naming none,
        // which the nearest loop takes.
        func endsRound(of loop: Name?) -> Bool {
            guard case let .round(target) = self else { return false }

            return target == nil || target == loop
        }

        // Whether this lands at the end of the loop under this name: a
        // `break` naming it or none, and a round ended the same way, since
        // the loop may end after it.
        func endsLoop(_ loop: Name?) -> Bool {
            guard case let .loop(target) = self else { return endsRound(of: loop) }

            return target == nil || target == loop
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The way that goes on past here, or nil where every way left.
    var going: Way? = Way()

    // The ways that left, by where each lands. Each is the whole way from the
    // start of the flow to its leave, so the construct a way lands at meets it
    // with the ways that went on as they are.
    var left: [Reach: [Way]] = [:]

    // What every `return` inside here carried out of the procedure, each with
    // the value it carried where that is a constant, and where it was written.
    // Nothing absorbs one, so this only ever gathers on the way up. Kept apart
    // rather than joined, so each is held to the declaration on its own: two
    // that disagree join to `any`, and `any` fits everything.
    var answered: [(reading: LoweredType, value: Value?, place: Place)] = []

    // The names read here that the body this flow came out of did not
    // declare. With what was written, what a closure takes from where it was
    // written.
    var read: Set<Name> = []

    // Whether every way through leaves.
    var leaves: Bool {
        going == nil
    }

    // Every way, the one that goes on and the ones that left.
    var ways: [Way] {
        (going.map { going in [going] } ?? []) + left.values.flatMap { ways in ways }
    }

    // Every name the flow reached from outside: read or written, on any way.
    var reached: Set<Name> {
        ways.reduce(read) { reached, way in reached.union(way.written.keys) }
    }

    // MARK: - Initializer
    // MARK: - Public
    // A write on the way that goes on.
    mutating func land(_ later: (type: LoweredType, definite: Bool), on name: Name) {
        going?.land(later, on: name)
    }

    // A box taken on the way that goes on.
    mutating func hold(_ type: LoweredType, on name: Name) {
        going?.hold(type, on: name)
    }

    // The way that goes on may end here by a failure, which lands at the
    // attempt around it with everything the way did so far.
    mutating func fail() {
        guard let going else { return }

        left[.failure, default: []].append(going)
    }

    // The same flow seen from outside a body that declared these names: what
    // it did to them is that body's own.
    func outside(_ locals: Set<Name>) -> Flow {
        var seen = self

        seen.going = going?.outside(locals)
        seen.left = left.mapValues { ways in ways.map { way in way.outside(locals) } }
        seen.read = read.subtracting(locals)

        return seen
    }

    // The way that goes on, on what the names around the flow hold. A box
    // that declared its type was checked where it was written, so a write into
    // it changes nothing about what it holds. A box taken holds what it was
    // taken as from then on.
    func apply(to environment: inout [Name: Binding]) {
        guard let going else { return }

        for (name, write) in going.written {
            guard let current = environment[name], current.holding == .assigned else { continue }

            environment[name] = Binding(.assigned, write.definite ? write.type : current.type.joined(write.type))
        }

        for (name, type) in going.held {
            guard let current = environment[name], current.holding == .assigned else { continue }

            environment[name] = Binding(.held(type), current.type)
        }
    }

    // A way out took this flow with it: the way that went on left here, and
    // lands where the leave lands.
    func leaving(to reach: Reach) -> Flow {
        var left = self

        if let going {
            left.left[reach, default: []].append(going)
        }

        left.going = nil

        return left
    }

    // The construct the ways that land here stop at. They go on from it with
    // the way that went on through it, each met with the others, and nothing
    // about any of them is certain: the construct may not have run, or may have
    // stopped anywhere. Ways that land further out stay aside.
    func absorbed(where lands: (Reach) -> Bool, meeting: Meeting) rethrows -> Flow {
        var stopped = self
        var going = self.going ?? Way()

        for reach in left.keys where lands(reach) {
            for way in left[reach] ?? [] {
                going = try going.joined(with: way, meeting: meeting)
            }

            stopped.left[reach] = nil
        }

        stopped.going = going.indefinite()

        return stopped
    }

    // One thing ran after another. The way that goes on goes through both; a
    // way that left the second went through the first on its way out.
    func followed(by second: Flow) -> Flow {
        guard let first = going else { return self }

        var flowed = self

        flowed.going = second.going.map { later in first.followed(by: later) }

        for (reach, ways) in second.left {
            flowed.left[reach, default: []] += ways.map { way in first.followed(by: way) }
        }

        flowed.answered += second.answered
        flowed.read.formUnion(second.read)

        return flowed
    }

    // One of two ways ran. The ways that go on meet; the ways that left stay
    // apart, each by where it lands.
    func joined(with declined: Flow, meeting: Meeting) rethrows -> Flow {
        var flowed = Flow()

        switch (going, declined.going) {
        case let (mine?, theirs?):
            flowed.going = try mine.joined(with: theirs, meeting: meeting)

        case let (mine?, nil):
            flowed.going = mine

        case let (nil, theirs?):
            flowed.going = theirs

        case (nil, nil):
            flowed.going = nil
        }

        flowed.left = left.merging(declined.left) { mine, theirs in mine + theirs }
        flowed.answered = answered + declined.answered
        flowed.read = read.union(declined.read)

        return flowed
    }

    // MARK: - Private
}
