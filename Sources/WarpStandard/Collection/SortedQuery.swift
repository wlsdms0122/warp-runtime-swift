//
//  SortedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The elements in order, for numbers or for strings.
struct SortedQuery: Query {
    // What this takes: the array, whose element is bounded by the shared
    // ground's `Comparable`. Ordering is one question wherever it is asked, so
    // the membership that answers it for `lessThan` answers it here.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter {
            Parameter(
                type: .array(.parameter(name: "Element", constraint: "std.Comparable"))
            )
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, and answered in the spelling the receiver arrived in.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        return receiver.respelled(try sorted(elements))
    }

    // MARK: - Private
    // Numbers order among themselves and strings among themselves. A mixed
    // array has no order this could answer with, so it says so rather than
    // picking one. One order for everything that has one. `Value.order`, so a
    // whole beside a fraction sorts by worth exactly at every size. An element
    // that orders with nothing (a fraction that is not a number, a kind that
    // does not order, a mixed array) is refused rather than placed: any
    // placement would be an order this could not answer for.
    //
    // The elements are read out once and the three passes below run on that,
    // because what arrives is a projection that makes each element as it is
    // asked for. Walking it four times would make a compact spelling's every
    // byte four times over.
    private func sorted(_ projected: some Collection<Value>) throws -> [Value] {
        let elements = Array(projected)

        // Every element must order with itself (which refuses the kinds that do
        // not order and the fraction that is not a number) and with its
        // neighbour, which refuses a mixed array: ordering is transitive inside
        // a kind and never crosses one, so the chain reaches every pair the
        // sort will ask about.
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
