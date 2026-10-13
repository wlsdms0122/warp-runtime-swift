//
//  Substitution.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// What a call put in a declaration's type parameters, and where it put two
// things in one.
//
// A parameter read two ways has no answer, so the disagreement is kept beside
// the first reading.
struct Substitution: Sendable {
    // A value that arrived where a composition stands, beside what the
    // composition holds it to, and whether the slot takes null as well.
    struct Held: Sendable {
        // MARK: - Property
        let reading: LoweredType
        let bounds: [Name]
        let orNull: Bool

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // How a reading of a parameter joins what it is already read as.
    enum Join: Sendable {
        // Only where one holds the other, and a disagreement otherwise.
        case holdingBoth

        // What procedures handed take, where one takes the other: the one
        // both take, which is the one the other accepts, and a disagreement
        // otherwise.
        case takenByBoth
    }

    // MARK: - Property
    // What each type parameter is read as: the join of its readings, or,
    // where two disagreed, the first of those two.
    private(set) var readings: [Name: LoweredType] = [:]

    // For a parameter read two ways, the second of the two that disagreed.
    // Keeping both is what lets a refusal name them, and a parameter read two
    // ways is joined no further.
    private(set) var disagreeing: [Name: LoweredType] = [:]

    // The readings of each parameter that what it is read as does not say,
    // as they were read: a join with `Any` is `Any`, and a whole literal
    // beside a fraction is held as the fraction the call hands on.
    private(set) var apart: [Name: [LoweredType]] = [:]

    // For a member whose base was read as something giving it no type, what
    // the base was read as, by the member's label.
    private(set) var ungiven: [Name: (of: Name, name: Name, base: LoweredType)] = [:]

    // For a member a declaration says is a type, where what fills its base
    // gives another, the two, by the member's label.
    private(set) var unsame: [Name: (said: LoweredType, given: LoweredType)] = [:]

    // MARK: - Initializer
    init() {}

    // What a call puts in the type parameters `declared` names, read by
    // holding each declared type beside what arrived at its position. What
    // a procedure arriving takes fills a parameter only where nothing that
    // arrived does.
    init(filling declared: [LoweredType], against given: [LoweredType], in table: LoweredTypeTable) {
        var taking = Substitution()
        var holding: [Held] = []

        for (slot, reading) in zip(declared, given) {
            slot.binding(against: reading, into: &self, taking: &taking, holding: &holding, in: table)
        }

        read(takenBy: taking)
    }

    // MARK: - Public
    // Each member of `members` whose base this reads, read as what fills the
    // base gives under its name, which is what decides it: the type's member,
    // or a type parameter's own. The contracts bounding a base are what
    // `declared` holds that parameter to. `said` is what a declaration says
    // some of them are, which what fills their bases has to give, and a
    // member it does not name stands as one more type parameter, read where
    // its base is. `reading` is what the procedure being read reads a member
    // of one of its own parameters as, where it says more of one than the
    // contracts do.
    mutating func derive(
        _ members: [Name: (of: Name, name: Name)],
        over declared: [LoweredType],
        said: [Name: LoweredType] = [:],
        reading: [Name: LoweredType] = [:],
        in table: LoweredTypeTable
    ) {
        let bases = declared.reduce(into: [Name: [Name]]()) { bases, type in
            bases.merge(type.typeParameters) { first, _ in first }
        }
        var given: [Name: LoweredType] = [:]

        for (label, member) in members.sorted(by: { $0.key < $1.key }) {
            guard let base = readings[member.of] else { continue }

            guard
                let derived = table.member(member.name, of: base, among: bases[member.of] ?? [])?
                    .replacingParameters(reading)
            else {
                ungiven[label] = (member.of, member.name, base)

                continue
            }

            guard let same = said[label] else {
                read(label, as: derived, in: table)

                continue
            }

            var taking = Substitution()
            var holding: [Held] = []

            same.binding(against: derived, into: &self, taking: &taking, holding: &holding, in: table)
            given[label] = derived
        }

        for (label, derived) in given.sorted(by: { $0.key < $1.key }) {
            guard let same = said[label] else { continue }

            let filled = same.filling(readings)

            if !derived.reads(as: filled) {
                unsame[label] = (filled, derived)
            }

            readings[label] = derived
        }
    }

    // Why a member has no answer, or nil where every member read has one:
    // its base read as what gives it no type, or what fills its base giving
    // another type than the declaration says. Named in label order.
    func memberRefusal(in table: LoweredTypeTable) -> String? {
        if let ungiven = ungiven.sorted(by: { $0.key < $1.key }).first?.value {
            return "'\(ungiven.of)' is read as \(ungiven.base.rendered(in: table)), which gives no type"
                + " '\(ungiven.name)' for `\(TypeExpression.member(of: ungiven.of, name: ungiven.name).rendered)`."
                + " A member is what one type gives, where a claim within reach says it answers a contract"
                + " asking it"
        }

        if let (label, unsame) = unsame.sorted(by: { $0.key < $1.key }).first {
            return "'\(label)' is \(unsame.given.rendered(in: table)), and the declaration says it is"
                + " \(unsame.said.rendered(in: table))"
        }

        return nil
    }

    // What a parameter is held to its bounds as: what it is read as, and each
    // reading that does not say.
    func everyReading(of parameter: Name) -> [LoweredType] {
        (readings[parameter].map { reading in [reading] } ?? []) + apart[parameter, default: []]
    }

    // Why a parameter read two ways has no answer, both readings named, or
    // nil where it was read one way. The build refuses a call in these words
    // and a door the values it fills a declaration's parameters from.
    func disagreement(of parameter: Name, in table: LoweredTypeTable) -> String? {
        guard let first = readings[parameter], let second = disagreeing[parameter] else { return nil }

        return "'\(parameter)' is read as \(first.rendered(in: table)) and as \(second.rendered(in: table))"
    }

    // Why a call has no answer, each parameter read two ways named in name
    // order, or nil where every one was read one way.
    func disagreements(in table: LoweredTypeTable) -> String? {
        guard !disagreeing.isEmpty else { return nil }

        return disagreeing.keys.sorted().compactMap { parameter in disagreement(of: parameter, in: table) }
            .joined(separator: ", ")
    }

    // Why a reading of a parameter does not answer a contract its bounds
    // name, or nil where every reading answers each.
    func unanswered(_ parameter: Name, bounds: Set<Name>, in table: LoweredTypeTable) -> String? {
        for reading in everyReading(of: parameter) {
            for name in bounds.sorted() {
                if let refusal = table.refusal(
                    of: reading,
                    answering: name,
                    orNull: false,
                    as: "'\(parameter)' is read as"
                ) {
                    return refusal
                }
            }
        }

        return nil
    }

    // Why a value of more than one type fills a bounded parameter it cannot,
    // or nil where none does. A bounded parameter is one type wherever it
    // stands, and a value of a contract is of whichever type answers it, and
    // one of what may be null of the type or `Null`, so two of them, or one
    // inside a list or a map, are not known to be one type. Standing
    // alone at one position of `slots`, the value is the one thing the
    // parameter stands for, and the call reads the parameter the way it read
    // the value.
    func severalTypes(
        of parameter: Name,
        bounds: Set<Name>,
        over slots: [LoweredType],
        in table: LoweredTypeTable
    ) -> String? {
        guard !bounds.isEmpty else { return nil }

        let valueOfSeveral = everyReading(of: parameter).first { reading in
            switch reading {
            case let .composition(read):
                return !read.isEmpty

            case .nullable:
                return true

            default:
                return false
            }
        }

        guard let valueOfSeveral else { return nil }

        let standing = slots.filter { slot in slot.typeParameters[parameter] != nil }

        if standing.count == 1, case let .parameter(alone, _) = standing[0].slotUnwrapped, alone == parameter {
            return nil
        }

        let spelled = parameter == TypeSpelling.selfType ? TypeExpression.selfType : .parameter(name: parameter)

        return "'\(parameter)' is read as \(valueOfSeveral.rendered(in: table)), a value of more than one"
            + " type, and `\(spelled.rendered)` is one type wherever it stands. A value of a contract"
            + " or of what may be null fills a bounded parameter only where the parameter stands alone"
            + " at one position"
    }

    // A parameter read once more, joined with what it is already read as by
    // `join`: holding both, only where one takes the other (a whole
    // literal and a fraction, and the same through lists, maps and `?`),
    // with the table, because a reading may stand on a row and the type that
    // row holds; or, for what procedures handed take, the one both take. A
    // parameter read as `Any` anywhere is `Any` there.
    //
    // Where two do not join, the first reading is kept, so that what is
    // reported names both, and so that everything downstream sees one answer
    // rather than a parameter that is two things.
    mutating func read(
        _ parameter: Name,
        as given: LoweredType,
        joining join: Join = .holdingBoth,
        in table: LoweredTypeTable
    ) {
        // A reading that leaves, or an empty list's element, holds no value,
        // so it fills the parameter only where nothing else does.
        guard let already = readings[parameter], already != .never else {
            readings[parameter] = given

            return
        }

        guard already != given, given != .never else { return }

        // What else a parameter read two ways is read as is kept apart, so
        // that it is still held to the bounds.
        guard disagreeing[parameter] == nil else {
            apart[parameter, default: []].append(given)

            return
        }

        let both = switch join {
        case .holdingBoth:
            already.holdingBoth(given, in: table)

        case .takenByBoth:
            already.accepts(given, in: table) ? given : given.accepts(already, in: table) ? already : nil
        }

        // Two that do not join stay as they were read: the first is what the
        // parameter is read as, and the second is kept apart as well, so that
        // both are still held to the bounds.
        guard let both else {
            disagreeing[parameter] = given
            apart[parameter, default: []].append(given)

            return
        }

        // What a reading reads as once the join writes it, so a whole literal
        // the join reads as a fraction is held to the bounds as the fraction
        // the call hands on. What a procedure takes is no value, so the wider
        // of two it takes is held to nothing.
        for reading in [already, given] where join != .takenByBoth && both.written(reading, in: table) != both {
            apart[parameter, default: []].append(both.written(reading, in: table))
        }

        readings[parameter] = both
    }

    // What another walk read, read into this one: what it read each
    // parameter as, once more, and what it kept apart.
    //
    // Where the other read a parameter two ways and this one did not, the
    // other's two are the ones reported, and what this one read the
    // parameter as is kept apart. Where this one already read it two ways,
    // its own two stay.
    mutating func read(_ other: Substitution, joining join: Join = .holdingBoth, in table: LoweredTypeTable) {
        for (parameter, second) in other.disagreeing.sorted(by: { $0.key < $1.key })
            where disagreeing[parameter] == nil {
            if let already = readings[parameter] {
                apart[parameter, default: []].append(already)
            }

            readings[parameter] = other.readings[parameter]
            disagreeing[parameter] = second
        }

        for (parameter, reading) in other.readings.sorted(by: { $0.key < $1.key })
            where other.disagreeing[parameter] == nil {
            read(parameter, as: reading, joining: join, in: table)
        }

        for (parameter, readings) in other.apart.sorted(by: { $0.key < $1.key }) {
            apart[parameter, default: []].append(contentsOf: readings)
        }
    }

    // What procedures arriving take, read where nothing else reads a
    // parameter, or only what holds no value does.
    mutating func read(takenBy taking: Substitution) {
        for (parameter, reading) in taking.readings where readings[parameter, default: .never] == .never {
            readings[parameter] = reading
            disagreeing[parameter] = taking.disagreeing[parameter]
            apart[parameter] = taking.apart[parameter]
        }
    }

    // MARK: - Private
}
