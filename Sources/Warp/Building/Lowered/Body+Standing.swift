//
//  Body+Standing.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// What a body stands on: the frame slots it names, and the closures it stands
// up beside what each of those takes with it.
//
// One walk answers all of them, because they are read off the same places, and
// one door asks it: the row the body belongs to, handed what only the list
// beside it knows.
extension Body {
    struct Standing {
        // MARK: - Property
        // Every slot of this frame the body names, whether it reads it or
        // writes it. A frame that does not hold one of these is a frame the
        // body does not fit.
        private(set) var slots: [Int] = []

        // The runs of slots the body takes whole. A range is not a slot and
        // not a set of them either: a run is read as one, so an empty one whose
        // bounds stand outside the frame is an array reached past its end just
        // as a full one is. Held as a range so that what it is cannot be
        // mistaken for what it holds.
        private(set) var extents: [Range<Int>] = []

        // The closures the body stands up: which one of its document's it is,
        // and where what it takes with it stands in the closure's own frame.
        private(set) var closures: [(number: Int, inner: [Int])] = []

        // The numbers its calls reach, as its document gave them. What each
        // one stands for is the link's answer, so what is asked of them here
        // is only that this document gave them at all.
        private(set) var calls: [(number: Int, arguments: Int)] = []

        // The type numbers its code stands on, kept apart because a document
        // numbers its types and its memberships in two spaces.
        private(set) var types: [Int] = []
        private(set) var memberships: [Int] = []

        // MARK: - Initializer
        // MARK: - Internal
        mutating func stand(on slot: Int) {
            slots.append(slot)
        }

        mutating func stand(over run: Range<Int>) {
            extents.append(run)
        }

        mutating func stand(calling number: Int, handing arguments: Int) {
            calls.append((number: number, arguments: arguments))
        }

        mutating func stand(on type: LoweredType) {
            switch type {
            case let .named(number):
                types.append(number)

            case let .parameter(_, bounds), let .composition(bounds):
                for bound in bounds {
                    guard case let .membership(number) = bound else { continue }

                    memberships.append(number)
                }

            case let .array(held), let .dictionary(held), let .variable(held),
                let .inout(held), let .nullable(held):
                stand(on: held)

            case let .record(record):
                record.fields.forEach { field in stand(on: field) }

            case let .procedure(parameters, returns, _, _):
                parameters?.forEach { parameter in stand(on: parameter.type) }
                returns.map { answer in stand(on: answer) }

            default:
                return
            }
        }

        mutating func stand(up number: Int, taking inner: [Int]) {
            closures.append((number: number, inner: inner))
        }
    }
}

extension Body {
    var standing: Standing {
        var standing = Standing()

        walk { node in
            node.stand(in: &standing)

            return true
        }

        return standing
    }
}

extension Body.Node {
    // What this one node stands on, apart from what nests in it.
    func stand(in standing: inout Body.Standing) {
        switch self {
        case let .instruction(instruction):
            switch instruction.binding {
            case let .bind(slot, settling)?, let .declare(slot, settling)?:
                standing.stand(on: slot)
                settling.map { type in standing.stand(on: type) }

            case let .assign(address, settling)?:
                address.stand(in: &standing)
                settling.map { type in standing.stand(on: type) }

            case nil:
                break
            }

        case let .operation(operation):
            switch operation {
            case let .local(address):
                address.stand(in: &standing)

            // The outer slot is this frame's and the inner one is the
            // closure's own, so the two are counted apart.
            case let .closure(number, captures):
                captures.forEach { outer, _ in standing.stand(on: outer) }
                standing.stand(up: number, taking: captures.map { _, inner in inner })

            case let .cast(_, type, _):
                standing.stand(on: type)

            case let .loop(_, _, round, keeps):
                round.map { round in standing.stand(on: round) }
                keeps.map { kept in standing.stand(over: kept) }

            case let .attempt(_, _, failure):
                failure.map { failure in standing.stand(on: failure) }

            case let .call(call):
                standing.stand(calling: call.procedure, handing: call.arguments.count)
                call.handed.forEach { handed in handed.address.stand(in: &standing) }

            case let .dispatch(dispatch):
                dispatch.arguments.values.forEach { argument in
                    guard case let .reference(address) = argument else { return }

                    address.stand(in: &standing)
                }

            case .literal, .array, .record, .apply, .block, .conditional, .leave:
                break
            }
        }
    }
}

extension Address {
    func stand(in standing: inout Body.Standing) {
        standing.stand(on: slot)
        steps.forEach { step in step.stand(in: &standing) }
    }
}

extension Step {
    func stand(in standing: inout Body.Standing) {
        guard case let .at(address, _) = self else { return }

        address.stand(in: &standing)
    }
}
