//
//  LoweredBody.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

struct LoweredBody: Sendable {
    enum Node {
        case operation(Operation)
        case instruction(Instruction)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // What this one node stands on, apart from what nests in it.
        func stand(in standing: inout LoweredBody.Standing) {
            switch self {
            case let .instruction(instruction):
                switch instruction.binding {
                case let .bind(slot)?, let .declare(slot)?:
                    standing.stand(on: slot)

                case let .assign(address)?:
                    address.stand(in: &standing)

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

                case let .loop(_, _, round):
                    round.map { round in standing.stand(on: round) }

                case let .attempt(_, _, failure):
                    failure.map { failure in standing.stand(on: failure) }

                case let .call(call):
                    standing.stand(calling: call.procedure, handing: call.arguments.count, inPlaceAt: call.handed.map(\.position))
                    call.handed.forEach { handed in handed.address.stand(in: &standing) }

                case let .apply(_, arguments, _):
                    arguments.forEach { argument in argument.stand(in: &standing) }

                case let .dispatch(dispatch):
                    dispatch.arguments.forEach { argument in argument.stand(in: &standing) }

                case .literal, .array, .struct, .dictionary, .cast, .conditional, .leave:
                    break
                }
            }
        }

        // MARK: - Private
    }

    // What a body stands on: the frame slots it names, and the closures it stands
    // up beside what each of those takes with it.
    //
    // One walk answers all of them, because they are read off the same places, and
    // one caller asks it: the row the body belongs to, handed what only the list
    // beside it knows.
    struct Standing {
        // MARK: - Property
        // Every slot of this frame the body names, whether it reads it or
        // writes it. A frame that does not hold one of these is a frame the
        // body does not fit.
        private(set) var slots: [Int] = []

        // The closures the body stands up: which one of its document's it is,
        // and where what it takes with it stands in the closure's own frame.
        private(set) var closures: [(number: Int, inner: [Int])] = []

        // The numbers its calls reach, as its document gave them, with how
        // many arguments each stands and where it hands in place. What each
        // number stands for is the link's answer, so what is asked of them
        // here is only that this document gave them at all.
        private(set) var calls: [(number: Int, arguments: Int, inPlace: [Int])] = []

        // MARK: - Initializer
        // MARK: - Public
        mutating func stand(on slot: Int) {
            slots.append(slot)
        }

        mutating func stand(calling number: Int, handing arguments: Int, inPlaceAt positions: [Int]) {
            calls.append((number: number, arguments: arguments, inPlace: positions))
        }

        mutating func stand(up number: Int, taking inner: [Int]) {
            closures.append((number: number, inner: inner))
        }

        // MARK: - Private
    }

    // MARK: - Property
    let instructions: [Instruction]
    let result: Operation?

    var standing: Standing {
        var standing = Standing()

        walk { node in
            node.stand(in: &standing)

            return true
        }

        return standing
    }

    // MARK: - Initializer
    init(instructions: [Instruction], result: Operation?) {
        self.instructions = instructions
        self.result = result
    }

    // MARK: - Public
    // Every operation and instruction a body holds, outermost first. What a
    // reading of the code asks is answered node by node; how the code nests is
    // answered by each kind of node walking what it holds.
    //
    // A reading walks and a relocation rewrites (`rewritten`), and the two
    // stay apart: a reading stops where it has its answer and builds nothing.
    //
    // Whether the walk went the whole way. A visit answering false stops it.
    @discardableResult
    func walk(_ visit: (Node) -> Bool) -> Bool {
        instructions.allSatisfy { instruction in instruction.walk(visit) }
            && (result?.walk(visit) ?? true)
    }

    // Whether any node answers, stopping at the first that does.
    func contains(where predicate: (Node) -> Bool) -> Bool {
        !walk { node in !predicate(node) }
    }

    // The same code with every operation and every type in it replaced, innermost
    // first: an operation is handed over with what nests in it already rewritten.
    // Which numbers a relocation answers is its own to say, node by node; how the
    // code nests is said by each kind of node rewriting what it holds.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> LoweredBody {
        LoweredBody(
            instructions: try instructions.map { instruction in
                try instruction.rewritten(operation: operation, type: type)
            },
            result: try result.map { result in try result.rewritten(operation: operation, type: type) }
        )
    }

    // MARK: - Private
}
