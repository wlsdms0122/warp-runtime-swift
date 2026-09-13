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
//
// `reads` asks a further question over the same shape and stays apart: it
// counts only the slots a body's value depends on, and leaves out the ones it
// writes.
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

        // MARK: - Initializer
        // MARK: - Internal
        mutating func stand(on slot: Int) {
            slots.append(slot)
        }

        mutating func stand(over run: Range<Int>) {
            extents.append(run)
        }

        mutating func stand(up number: Int, taking inner: [Int]) {
            closures.append((number: number, inner: inner))
        }
    }
}

extension Body {
    var standing: Standing {
        var standing = Standing()

        stand(in: &standing)

        return standing
    }

    func stand(in standing: inout Body.Standing) {
        instructions.forEach { instruction in instruction.stand(in: &standing) }
        result?.stand(in: &standing)
    }
}

extension Instruction {
    func stand(in standing: inout Body.Standing) {
        switch binding {
        case let .bind(slot, _)?, let .declare(slot, _)?:
            standing.stand(on: slot)

        case let .assign(address, _)?:
            address.stand(in: &standing)

        case nil:
            break
        }

        code.stand(in: &standing)
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

extension Argument {
    func stand(in standing: inout Body.Standing) {
        switch self {
        case let .value(operation):
            operation.stand(in: &standing)

        case let .reference(address):
            address.stand(in: &standing)
        }
    }
}

extension Operation {
    func stand(in standing: inout Body.Standing) {
        switch self {
        case .literal:
            break

        case let .local(address):
            address.stand(in: &standing)

        case let .array(elements):
            elements.forEach { element in element.stand(in: &standing) }

        case let .record(record):
            record.fields.forEach { field in field.stand(in: &standing) }

        // The outer slot is this frame's and the inner one is the closure's
        // own, so the two are counted apart.
        case let .closure(number, captures):
            captures.forEach { outer, _ in standing.stand(on: outer) }
            standing.stand(up: number, taking: captures.map { _, inner in inner })

        case let .apply(callee, arguments):
            callee.stand(in: &standing)
            arguments.forEach { _, argument in argument.stand(in: &standing) }

        case let .cast(read, _, _):
            read.stand(in: &standing)

        case let .block(body):
            body.stand(in: &standing)

        case let .conditional(condition, then: then, else: otherwise):
            condition.stand(in: &standing)
            then.forEach { instruction in instruction.stand(in: &standing) }
            otherwise?.forEach { instruction in instruction.stand(in: &standing) }

        case let .loop(while: condition, body: body, round: round, keeps: keeps):
            condition.stand(in: &standing)
            body.stand(in: &standing)
            standing.stand(on: round)
            if let kept = keeps {
                standing.stand(over: kept)
            }

        case let .attempt(body, rescue: rescue, failure: failure):
            body.stand(in: &standing)
            rescue.stand(in: &standing)
            standing.stand(on: failure)

        case let .call(call):
            call.receiver?.stand(in: &standing)
            call.arguments.forEach { argument in argument?.stand(in: &standing) }
            call.handed.forEach { handed in handed.address.stand(in: &standing) }

        // What a call through a contract hands over is in `arguments`. The
        // calls beside it are the link's copy of the same, so walking those
        // too would count one fact twice.
        case let .dispatch(dispatch):
            dispatch.receiver.stand(in: &standing)
            dispatch.arguments.forEach { _, argument in argument.stand(in: &standing) }

        case let .leave(_, _, read):
            read?.stand(in: &standing)
        }
    }
}
