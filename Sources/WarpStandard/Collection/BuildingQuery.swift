//
//  BuildingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Making an array out of another one. Nothing is written in place: each answers
// a new array, which is what a language whose names are fixed by default can
// offer.
//
// Without these an array's length is whatever the text wrote down, because the
// only other way to build one is `each`, which answers one element for every
// element it was given.
public struct BuildingQuery: Query {
    public enum Building: Sendable {
        case appending
        case prepending
        case dropFirst
        case dropLast
        case sorted
    }

    // MARK: - Property
    private let building: Building

    // MARK: - Initializer
    public init(_ building: Building) {
        self.building = building
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, and answered in the spelling the receiver arrived in: each
        // of these is the receiver's own elements, so a compact one stays
        // compact — until an element that is not a byte is put among them,
        // which `respelled` reads for itself.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        switch building {
        // Only the arriving element decides the answer's spelling, so only it
        // is looked at — the ones already there are what the receiver spells
        // them as.
        case .appending:
            return receiver.adding(question["value"], atFront: false)

        case .prepending:
            return receiver.adding(question["value"], atFront: true)

        // Dropping from an array that has nothing left answers the empty array
        // rather than failing: taking none of nothing is nothing. Said by
        // position, because neither of these has to look at an element — so a
        // compact spelling is trimmed as what it holds.
        case .dropFirst:
            return receiver.elements(at: (0 ..< elements.count).dropFirst())

        case .dropLast:
            return receiver.elements(at: (0 ..< elements.count).dropLast())

        case .sorted:
            return receiver.respelled(try sorted(elements))
        }
    }

    // MARK: - Private
    // Numbers order among themselves and strings among themselves. A mixed array
    // has no order this could answer with, so it says so rather than picking one.
    // One order for everything that has one — `Value.order`, so a whole
    // beside a fraction sorts by worth exactly at every size. An element that
    // orders with nothing (a fraction that is not a number, a kind that does
    // not order, a mixed array) is refused rather than placed: any placement
    // would be an order this could not answer for.
    //
    // The elements are read out once and the three passes below run on that,
    // because what arrives is a projection that makes each element as it is
    // asked for — walking it four times would make a compact spelling's every
    // byte four times over.
    private func sorted(_ projected: some Collection<Value>) throws -> [Value] {
        let elements = Array(projected)

        // Every element must order with itself — which refuses the kinds that
        // do not order and the fraction that is not a number — and with its
        // neighbour, which refuses a mixed array: ordering is transitive
        // inside a kind and never crosses one, so the chain reaches every
        // pair the sort will ask about.
        guard
            elements.allSatisfy({ element in Value.order(element, element) != nil }),
            zip(elements, elements.dropFirst())
                .allSatisfy({ pair in Value.order(pair.0, pair.1) != nil })
        else {
            throw ExecutionError(
                "sorted asks an array of numbers or an array of strings,"
                    + " every element ordering with the rest"
            )
        }

        return elements.sorted { left, right in
            Value.order(left, right) == .orderedAscending
        }
    }
}
