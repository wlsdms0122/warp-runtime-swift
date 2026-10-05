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
// the first reading rather than read as `any`: `any` is what a declaration
// says when it said nothing.
struct Substitution: Sendable {
    // A value that arrived where a composition stands, beside what the
    // composition holds it to, and whether the slot takes null as well.
    struct Held: Sendable {
        // MARK: - Property
        let reading: LoweredType
        let bounds: [LoweredType.Bound]
        let orNull: Bool

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // How a reading of a parameter joins what it is already read as: only
    // where one holds the other, and a disagreement otherwise, or part by
    // part, as a list literal's elements do, and never a disagreement.
    enum Join: Sendable {
        case holdingBoth
        case partByPart
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
    // as they were read: a join with `any` is `any`, and a record's fields
    // joined say nothing of each field.
    private(set) var apart: [Name: [LoweredType]] = [:]

    // MARK: - Initializer
    // MARK: - Public
    // What a parameter is held to its bounds as: what it is read as, and each
    // reading that does not say.
    func everyReading(of parameter: Name) -> [LoweredType] {
        (readings[parameter].map { reading in [reading] } ?? []) + apart[parameter, default: []]
    }

    // A parameter read once more. Two readings agree when one takes the other.
    // A list of numbers and a whole number are not a disagreement, they are a
    // parameter read once loosely and once tightly, and the loose reading is
    // the one that holds both. With the table, because a reading may stand on
    // a row and the type that row holds. Asking without it would call those
    // two a disagreement, which is the same question the build asks elsewhere
    // and answers correctly. Rigidly, because a parameter read here is the
    // calling body's own and nothing fills it: a whole number and a parameter
    // bounded to numbers are held by the parameter. A range meets anything by
    // its kind, so a range and the plain kind under it take each other both
    // ways, and so do two ranges that overlap; a declared record and a
    // nameless record of its fields take each other too. What holds both is
    // `holdingBoth`, and a parameter read as `any` anywhere is `any` there.
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
        guard let already = readings[parameter] else {
            readings[parameter] = given

            return
        }

        guard already != given else { return }

        // What else a parameter read two ways is read as is kept apart, so
        // that it is still held to the bounds.
        guard disagreeing[parameter] == nil else {
            apart[parameter, default: []].append(given)

            return
        }

        let both = switch join {
        case .holdingBoth:
            already.holdingBoth(given, in: table)

        case .partByPart:
            already.joinedPartByPart(given)
        }

        if already != both {
            apart[parameter, default: []].append(already)
        }

        if given != both {
            apart[parameter, default: []].append(given)
        }

        guard let both else {
            disagreeing[parameter] = given

            return
        }

        readings[parameter] = both
    }

    // What another walk read, read into this one: what it read each
    // parameter as, once more, and what it kept apart. Where it read one two
    // ways, its two are the ones reported, unless this one already read the
    // parameter two ways, and what this one read it as is kept apart.
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

    // MARK: - Private
}
